package com.yawmiyati.app;

import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.media.*;
import android.os.*;
import androidx.core.app.NotificationCompat;

public class AdhanService extends Service{
    MediaPlayer player;
    static final int ID=4801;

    @Override public void onCreate(){
        super.onCreate();
        PrayerAlarmReceiver.ensure(this);
        Notification n=new NotificationCompat.Builder(this,PrayerAlarmReceiver.SERVICE_CH)
                .setSmallIcon(R.drawable.ic_stat_yawmy)
                .setContentTitle("يومي — الأذان")
                .setContentText("حان وقت الصلاة")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setOngoing(true)
                .build();
        if(Build.VERSION.SDK_INT>=29){
            startForeground(ID,n,ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        }else{
            startForeground(ID,n);
        }
    }

    @Override public int onStartCommand(Intent i,int flags,int startId){
        try{
            if(player!=null){try{player.stop();}catch(Exception ignored){} player.release();}
            AudioAttributes aa=new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build();
            player=MediaPlayer.create(this,R.raw.adhan,aa,0);
            if(player==null)throw new IllegalStateException("Adhan audio unavailable");
            player.setWakeMode(getApplicationContext(),PowerManager.PARTIAL_WAKE_LOCK);
            player.setOnCompletionListener(mp->stopSelf());
            player.setOnErrorListener((mp,what,extra)->{stopSelf();return true;});
            player.start();
        }catch(Exception e){stopSelf();}
        return START_NOT_STICKY;
    }

    @Override public void onDestroy(){
        if(player!=null){
            try{if(player.isPlaying())player.stop();}catch(Exception ignored){}
            try{player.release();}catch(Exception ignored){}
            player=null;
        }
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent i){return null;}
}
