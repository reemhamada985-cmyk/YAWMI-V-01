package com.yawmiyati.app;

import android.app.*;
import android.content.*;
import android.media.AudioAttributes;
import android.net.Uri;
import androidx.core.app.NotificationCompat;

public class PrayerAlarmReceiver extends BroadcastReceiver{
    static final String ADHAN_CH="prayer_adhan_v3";
    static final String REM_CH="prayer_reminder_v3";
    static final String SERVICE_CH="prayer_service_v3";

    @Override public void onReceive(Context c,Intent i){
        String name=i.getStringExtra("name"); if(name==null)name="الصلاة";
        String kind=i.getStringExtra("kind");
        if("reminder".equals(kind))showReminder(c,name); else showAdhan(c,name);
    }

    static void ensure(Context c){
        if(android.os.Build.VERSION.SDK_INT>=26){
            NotificationManager nm=c.getSystemService(NotificationManager.class);
            // The notification itself is silent; AdhanService owns the audio playback.
            NotificationChannel a=new NotificationChannel(ADHAN_CH,"أذان الصلاة",NotificationManager.IMPORTANCE_HIGH);
            a.enableVibration(true); a.setSound(null,null); a.setShowBadge(true); nm.createNotificationChannel(a);

            NotificationChannel r=new NotificationChannel(REM_CH,"تذكيرات الصلاة",NotificationManager.IMPORTANCE_HIGH);
            r.enableVibration(true); nm.createNotificationChannel(r);

            NotificationChannel s=new NotificationChannel(SERVICE_CH,"تشغيل الأذان",NotificationManager.IMPORTANCE_LOW);
            s.setSound(null,null); s.enableVibration(false); s.setShowBadge(false); nm.createNotificationChannel(s);
        }
    }

    static PendingIntent open(Context c){
        Intent o=new Intent(c,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(c,9001,o,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
    }

    static void showAdhan(Context c,String name){
        ensure(c);
        NotificationCompat.Builder b=new NotificationCompat.Builder(c,ADHAN_CH)
                .setSmallIcon(R.drawable.ic_stat_yawmy)
                .setContentTitle("يومي — حان وقت صلاة "+name)
                .setContentText("حان الآن وقت صلاة "+name+".")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(open(c));
        NotificationManagerCompat.from(c).notify(2000+Math.abs(name.hashCode()),b.build());

        try{
            Intent s=new Intent(c,AdhanService.class).putExtra("name",name);
            if(android.os.Build.VERSION.SDK_INT>=26)c.startForegroundService(s); else c.startService(s);
        }catch(Exception ignored){}
    }

    static void showReminder(Context c,String name){
        ensure(c);
        NotificationCompat.Builder b=new NotificationCompat.Builder(c,REM_CH)
                .setSmallIcon(R.drawable.ic_stat_yawmy)
                .setContentTitle("يومي — تذكير صلاة "+name)
                .setContentText("اقترب موعد أذان "+name+".")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(open(c));
        NotificationManagerCompat.from(c).notify(3000+Math.abs(name.hashCode()),b.build());
    }

    static void showTest(Context c){
        ensure(c);
        NotificationCompat.Builder b=new NotificationCompat.Builder(c,REM_CH)
                .setSmallIcon(R.drawable.ic_stat_yawmy)
                .setContentTitle("يومي — اختبار الإشعارات")
                .setContentText("الإشعارات تعمل على هذا الجهاز.")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(open(c));
        NotificationManagerCompat.from(c).notify(3999,b.build());
    }
}
