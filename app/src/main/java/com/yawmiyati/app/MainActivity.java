package com.yawmiyati.app;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.webkit.*;
import android.widget.Toast;

import androidx.core.app.NotificationManagerCompat;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.webkit.WebViewAssetLoader;

import org.json.*;
import java.time.Instant;

public class MainActivity extends Activity {
    static final int REQ_NOTIFICATIONS = 7001;
    static final String PREFS="yawmiyati_native";
    static final String ALARMS="alarms";

    WebView webView;
    int insetTop=0, insetBottom=0;

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);

        // Android 15 enforces edge-to-edge for targetSdk 35. We keep the WebView
        // full-screen and send the real system-bar insets to the HTML layer.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);
        WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView())
                .setAppearanceLightStatusBars(true);
        WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView())
                .setAppearanceLightNavigationBars(true);

        webView = new WebView(this);
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setAllowFileAccessFromFileURLs(false);
        s.setAllowUniversalAccessFromFileURLs(false);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        webView.setBackgroundColor(Color.rgb(238,246,242));
        webView.setOverScrollMode(View.OVER_SCROLL_NEVER);

        final WebViewAssetLoader assetLoader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        webView.setWebViewClient(new WebViewClient(){
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetLoader.shouldInterceptRequest(request.getUrl());
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
                return assetLoader.shouldInterceptRequest(Uri.parse(url));
            }
            @Override public void onPageFinished(WebView v,String url){
                v.post(() -> {
                    applyInsetsToWeb();
                    syncNotificationStateToJs();
                });
            }
        });
        webView.addJavascriptInterface(new NativeBridge(this),"Android");
        setContentView(webView);

        ViewCompat.setOnApplyWindowInsetsListener(webView, (v, insets) -> {
            WindowInsetsCompat bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            insetTop = bars.top;
            insetBottom = bars.bottom;
            applyInsetsToWeb();
            return insets;
        });
        ViewCompat.requestApplyInsets(webView);

        createChannels();
        webView.loadUrl("https://appassets.androidplatform.net/assets/index.html");
    }

    void applyInsetsToWeb(){
        if(webView==null)return;
        String js = "document.documentElement.style.setProperty('--sys-top','"+insetTop+"px');"+
                "document.documentElement.style.setProperty('--sys-bottom','"+insetBottom+"px');";
        webView.evaluateJavascript("try{"+js+"}catch(e){}",null);
    }

    @Override public void onResume(){
        super.onResume();
        if(webView!=null) webView.postDelayed(() -> { syncNotificationStateToJs(); rescheduleAll(this); },250);
    }

    void syncNotificationStateToJs(){
        if(webView==null)return;
        boolean enabled=arePrayerNotificationsEnabled();
        webView.evaluateJavascript("try{if(window.onNativeNotificationState)window.onNativeNotificationState("+enabled+")}catch(e){}",null);
    }

    boolean areNotificationsEnabled(){ return NotificationManagerCompat.from(this).areNotificationsEnabled(); }

    boolean arePrayerNotificationsEnabled(){
        if(!areNotificationsEnabled()) return false;
        if(Build.VERSION.SDK_INT>=26){
            NotificationManager nm=getSystemService(NotificationManager.class);
            NotificationChannel adhan=nm.getNotificationChannel(PrayerAlarmReceiver.ADHAN_CH);
            if(adhan!=null && adhan.getImportance()==NotificationManager.IMPORTANCE_NONE)return false;
            NotificationChannel rem=nm.getNotificationChannel(PrayerAlarmReceiver.REM_CH);
            if(rem!=null && rem.getImportance()==NotificationManager.IMPORTANCE_NONE)return false;
        }
        return true;
    }

    boolean exactAlarmAllowed(){
        if(Build.VERSION.SDK_INT<31)return true;
        AlarmManager am=(AlarmManager)getSystemService(ALARM_SERVICE);
        return am.canScheduleExactAlarms();
    }

    void createChannels(){ PrayerAlarmReceiver.ensure(this); }

    void requestNotificationPermission(){
        createChannels();
        if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},REQ_NOTIFICATIONS);
        } else {
            syncNotificationStateToJs();
            maybeRequestExactAlarm();
            rescheduleAll(this);
        }
    }

    void maybeRequestExactAlarm(){
        if(Build.VERSION.SDK_INT>=31 && arePrayerNotificationsEnabled() && !exactAlarmAllowed()){
            try{
                startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:"+getPackageName())));
            }catch(Exception ignored){}
        }
    }

    @Override public void onRequestPermissionsResult(int r,String[] p,int[] g){
        super.onRequestPermissionsResult(r,p,g);
        if(r==REQ_NOTIFICATIONS){
            createChannels();
            syncNotificationStateToJs();
            if(arePrayerNotificationsEnabled()) maybeRequestExactAlarm();
            rescheduleAll(this);
        }
    }

    static int alarmId(String key){ return Math.abs(key.hashCode()); }

    public static void scheduleOne(Context ctx,String name,String iso,int reminderMinutes,boolean enabled){
        if(!enabled)return;
        try{
            long prayerAt=Instant.parse(iso).toEpochMilli();
            SharedPreferences sp=ctx.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
            JSONObject rec=new JSONObject().put("name",name).put("iso",iso).put("reminder",reminderMinutes);
            JSONArray arr;
            try{arr=new JSONArray(sp.getString(ALARMS,"[]"));}catch(Exception e){arr=new JSONArray();}
            JSONArray out=new JSONArray();
            for(int j=0;j<arr.length();j++){
                JSONObject x=arr.getJSONObject(j);
                if(!name.equals(x.optString("name")))out.put(x);
            }
            out.put(rec);
            sp.edit().putString(ALARMS,out.toString()).apply();
            scheduleAt(ctx,name,prayerAt,"adhan");
            if(reminderMinutes>0)scheduleAt(ctx,name,prayerAt-reminderMinutes*60000L,"reminder");
        }catch(Exception ignored){}
    }

    static void scheduleAt(Context ctx,String name,long at,String kind){
        if(at<=System.currentTimeMillis())return;
        AlarmManager am=(AlarmManager)ctx.getSystemService(Context.ALARM_SERVICE);
        Intent i=new Intent(ctx,PrayerAlarmReceiver.class)
                .putExtra("name",name)
                .putExtra("kind",kind);
        PendingIntent pi=PendingIntent.getBroadcast(ctx,alarmId(name+kind),i,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        try{
            if(Build.VERSION.SDK_INT>=23){
                if(Build.VERSION.SDK_INT>=31 && !am.canScheduleExactAlarms()) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pi);
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pi);
                }
            } else am.setExact(AlarmManager.RTC_WAKEUP,at,pi);
        }catch(SecurityException e){
            try{am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pi);}catch(Exception ignored){}
        }
    }

    static void cancelAllAlarms(Context ctx){
        AlarmManager am=(AlarmManager)ctx.getSystemService(Context.ALARM_SERVICE);
        String[] names={"الفجر","الظهر","العصر","المغرب","العشاء"};
        for(String n:names)for(String kind:new String[]{"adhan","reminder"}){
            Intent i=new Intent(ctx,PrayerAlarmReceiver.class);
            PendingIntent pi=PendingIntent.getBroadcast(ctx,alarmId(n+kind),i,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
            am.cancel(pi); pi.cancel();
        }
        ctx.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit().remove(ALARMS).apply();
    }

    static void rescheduleAll(Context ctx){
        try{
            SharedPreferences sp=ctx.getSharedPreferences(PREFS,Context.MODE_PRIVATE);
            JSONArray arr=new JSONArray(sp.getString(ALARMS,"[]"));
            for(int i=0;i<arr.length();i++){
                JSONObject x=arr.getJSONObject(i);
                long t=Instant.parse(x.getString("iso")).toEpochMilli();
                if(t>System.currentTimeMillis()){
                    scheduleAt(ctx,x.getString("name"),t,"adhan");
                    int rm=x.optInt("reminder",0);
                    if(rm>0)scheduleAt(ctx,x.getString("name"),t-rm*60000L,"reminder");
                }
            }
        }catch(Exception ignored){}
    }

    public static class NativeBridge{
        final MainActivity a;
        NativeBridge(MainActivity x){a=x;}
        @JavascriptInterface public void requestNotificationPermission(){a.runOnUiThread(a::requestNotificationPermission);}
        @JavascriptInterface public boolean areNotificationsEnabled(){return a.arePrayerNotificationsEnabled();}
        @JavascriptInterface public boolean isExactAlarmAllowed(){return a.exactAlarmAllowed();}
        @JavascriptInterface public void requestExactAlarmAccess(){
            if(Build.VERSION.SDK_INT>=31){
                try{a.startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:"+a.getPackageName())));}
                catch(Exception e){Toast.makeText(a,"افتح إعدادات المنبّهات والتذكيرات للتطبيق",Toast.LENGTH_LONG).show();}
            }
        }
        @JavascriptInterface public void schedulePrayerAlarm(String name,String iso,String json){
            try{
                JSONObject o=new JSONObject(json);
                boolean enabled=o.optBoolean("enabled",false) || o.optBoolean("sound",false);
                scheduleOne(a,name,iso,o.optInt("reminderMinutes",0),enabled);
            }catch(Exception ignored){}
        }
        @JavascriptInterface public void cancelPrayerAlarms(){cancelAllAlarms(a);}
        @JavascriptInterface public void sendTestNotification(){a.runOnUiThread(()->PrayerAlarmReceiver.showTest(a));}
        @JavascriptInterface public void setCity(String city){}
    }
}
