#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/com/example/automationassistant
mkdir -p app/src/main/res/xml
mkdir -p app/src/main/res/values

cat > settings.gradle.kts <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "AutomationAssistant"
include(":app")
EOF

cat > build.gradle.kts <<'EOF'
plugins {
    id("com.android.application") version "8.7.3" apply false
}
EOF

cat > app/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.automationassistant"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.automationassistant"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core:1.15.0")
}
EOF

cat > app/src/main/res/values/strings.xml <<'EOF'
<resources>
    <string name="app_name">Automation Assistant</string>
    <string name="accessibility_service_name">Automation Assistant Service</string>
    <string name="accessibility_service_description">Automation Assistant Service for controlled UI testing.</string>
</resources>
EOF

cat > app/src/main/res/values/styles.xml <<'EOF'
<resources>
    <style name="AppTheme" parent="Theme.AppCompat.Light.NoActionBar">
        <item name="android:fontFamily">sans</item>
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:colorAccent">#FF9800</item>
    </style>
</resources>
EOF

cat > app/src/main/res/xml/accessibility_service_config.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged|typeViewClicked|typeViewFocused|typeViewScrolled"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagReportViewIds|flagRetrieveInteractiveWindows|flagIncludeNotImportantViews"
    android:canPerformGestures="true"
    android:canRetrieveWindowContent="true"
    android:description="@string/accessibility_service_description"
    android:notificationTimeout="100"
    android:packageNames="com.weplay.game"
    android:settingsActivity="com.example.automationassistant.MainActivity" />
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <queries>
        <package android:name="com.weplay.game" />
    </queries>

    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:theme="@style/AppTheme"
        android:supportsRtl="true">

        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".AutomationForegroundService"
            android:exported="false"
            android:foregroundServiceType="specialUse" />

        <service
            android:name=".MyAutomationService"
            android:enabled="true"
            android:exported="true"
            android:label="@string/accessibility_service_name"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config" />
        </service>

        <receiver android:name=".AutomationAlarmReceiver" android:enabled="true" android:exported="false" />
        <receiver android:name=".BootReceiver" android:enabled="true" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
EOF

cat > app/src/main/java/com/example/automationassistant/AutomationConfig.java <<'EOF'
package com.example.automationassistant;

public final class AutomationConfig {
    private AutomationConfig() {}
    public static final String PREF_NAME = "automation_config";
    public static final String KEY_OPEN_INTERVAL = "openInterval";
    public static final String KEY_MODE = "mode";
    public static final String KEY_COLLECT_INTERVAL = "collectInterval";
    public static final String KEY_PERCENT_MIN = "percentMin";
    public static final String KEY_PERCENT_MAX = "percentMax";
    public static final String KEY_AUTOMATION_ENABLED = "automationEnabled";
    public static final String MODE_TIME = "A";
    public static final String MODE_PERCENT = "B";
    public static final String TARGET_PACKAGE = "com.weplay.game";
    public static final String ACTION_RUN_AUTOMATION = "com.example.automationassistant.ACTION_RUN_AUTOMATION";
    public static final String ACTION_START_FOREGROUND = "com.example.automationassistant.ACTION_START_FOREGROUND";
    public static final String ACTION_STOP_FOREGROUND = "com.example.automationassistant.ACTION_STOP_FOREGROUND";
    public static final int NOTIFICATION_ID = 1001;
    public static final int ALARM_REQUEST_CODE = 2001;
    public static final String CHANNEL_ID = "automation_foreground_channel";
}
EOF

cat > app/src/main/java/com/example/automationassistant/MainActivity.java <<'EOF'
package com.example.automationassistant;

import android.Manifest;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.widget.*;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

public class MainActivity extends AppCompatActivity {
    private EditText openIntervalInput, collectIntervalInput, percentMinInput, percentMaxInput;
    private RadioButton modeAButton, modeBButton;
    private LinearLayout modeAContainer, modeBContainer;
    private SharedPreferences preferences;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        preferences = getSharedPreferences(AutomationConfig.PREF_NAME, MODE_PRIVATE);
        buildUi();
        loadConfig();
        requestNotificationPermissionIfNeeded();
    }

    private void buildUi() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(20), dp(20), dp(20));

        TextView title = new TextView(this);
        title.setText("Automation Assistant");
        title.setTextSize(24);
        title.setGravity(Gravity.CENTER);
        root.addView(title, lp(16));

        root.addView(label("OPEN_INTERVAL / minutes"), lp(8));
        openIntervalInput = input("10");
        root.addView(openIntervalInput, lp(16));

        root.addView(label("Mode"), lp(8));
        RadioGroup group = new RadioGroup(this);
        group.setOrientation(RadioGroup.VERTICAL);
        modeAButton = new RadioButton(this);
        modeAButton.setText("Mode A - Fixed Time");
        modeAButton.setId(View.generateViewId());
        modeBButton = new RadioButton(this);
        modeBButton.setText("Mode B - Percentage Range");
        modeBButton.setId(View.generateViewId());
        group.addView(modeAButton);
        group.addView(modeBButton);
        group.setOnCheckedChangeListener((g, id) -> updateModeVisibility());
        root.addView(group, lp(16));

        modeAContainer = new LinearLayout(this);
        modeAContainer.setOrientation(LinearLayout.VERTICAL);
        modeAContainer.addView(label("COLLECT_INTERVAL / seconds"), lp(8));
        collectIntervalInput = input("300");
        modeAContainer.addView(collectIntervalInput, lp(16));
        root.addView(modeAContainer, lp(0));

        modeBContainer = new LinearLayout(this);
        modeBContainer.setOrientation(LinearLayout.VERTICAL);
        modeBContainer.addView(label("PERCENT_MIN"), lp(8));
        percentMinInput = input("20");
        modeBContainer.addView(percentMinInput, lp(16));
        modeBContainer.addView(label("PERCENT_MAX"), lp(8));
        percentMaxInput = input("40");
        modeBContainer.addView(percentMaxInput, lp(16));
        root.addView(modeBContainer, lp(0));

        Button start = new Button(this);
        start.setText("Save and Start");
        start.setOnClickListener(v -> saveAndStart());
        root.addView(start, lp(10));

        Button stop = new Button(this);
        stop.setText("Stop Automation");
        stop.setOnClickListener(v -> stopAutomation());
        root.addView(stop, lp(10));

        Button accessibility = new Button(this);
        accessibility.setText("Open Accessibility Settings");
        accessibility.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        root.addView(accessibility, lp(10));

        Button battery = new Button(this);
        battery.setText("Open Battery Optimization Settings");
        battery.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)));
        root.addView(battery, lp(10));

        TextView note = new TextView(this);
        note.setText("Enable Accessibility Service, allow notification, and set this app to unrestricted battery.");
        root.addView(note, lp(0));

        scroll.addView(root);
        setContentView(scroll);
    }

    private void loadConfig() {
        openIntervalInput.setText(String.valueOf(preferences.getInt(AutomationConfig.KEY_OPEN_INTERVAL, 10)));
        collectIntervalInput.setText(String.valueOf(preferences.getInt(AutomationConfig.KEY_COLLECT_INTERVAL, 300)));
        percentMinInput.setText(String.valueOf(preferences.getInt(AutomationConfig.KEY_PERCENT_MIN, 20)));
        percentMaxInput.setText(String.valueOf(preferences.getInt(AutomationConfig.KEY_PERCENT_MAX, 40)));
        if (AutomationConfig.MODE_PERCENT.equals(preferences.getString(AutomationConfig.KEY_MODE, AutomationConfig.MODE_TIME))) modeBButton.setChecked(true); else modeAButton.setChecked(true);
        updateModeVisibility();
    }

    private void saveAndStart() {
        int open = parse(openIntervalInput.getText().toString(), 10);
        int collect = parse(collectIntervalInput.getText().toString(), 300);
        int min = parse(percentMinInput.getText().toString(), 20);
        int max = parse(percentMaxInput.getText().toString(), 40);
        if (min > max) { int t = min; min = max; max = t; }
        preferences.edit()
                .putInt(AutomationConfig.KEY_OPEN_INTERVAL, open)
                .putString(AutomationConfig.KEY_MODE, modeBButton.isChecked() ? AutomationConfig.MODE_PERCENT : AutomationConfig.MODE_TIME)
                .putInt(AutomationConfig.KEY_COLLECT_INTERVAL, collect)
                .putInt(AutomationConfig.KEY_PERCENT_MIN, min)
                .putInt(AutomationConfig.KEY_PERCENT_MAX, max)
                .putBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, true)
                .apply();

        Intent service = new Intent(this, AutomationForegroundService.class);
        service.setAction(AutomationConfig.ACTION_START_FOREGROUND);
        ContextCompat.startForegroundService(this, service);
        scheduleFallbackAlarm(open);
        Toast.makeText(this, "Automation started", Toast.LENGTH_LONG).show();
        startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
    }

    private void stopAutomation() {
        preferences.edit().putBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, false).apply();
        Intent service = new Intent(this, AutomationForegroundService.class);
        service.setAction(AutomationConfig.ACTION_STOP_FOREGROUND);
        startService(service);
        cancelFallbackAlarm();
        Toast.makeText(this, "Automation stopped", Toast.LENGTH_LONG).show();
    }

    private void scheduleFallbackAlarm(int minutes) {
        AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(this, AutomationAlarmReceiver.class);
        i.setAction(AutomationConfig.ACTION_RUN_AUTOMATION);
        PendingIntent pi = PendingIntent.getBroadcast(this, AutomationConfig.ALARM_REQUEST_CODE, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        if (am == null) return;
        long when = System.currentTimeMillis() + minutes * 60L * 1000L;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:" + getPackageName())));
            am.set(AlarmManager.RTC_WAKEUP, when, pi);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, when, pi);
        }
    }

    private void cancelFallbackAlarm() {
        AlarmManager am = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(this, AutomationAlarmReceiver.class);
        i.setAction(AutomationConfig.ACTION_RUN_AUTOMATION);
        PendingIntent pi = PendingIntent.getBroadcast(this, AutomationConfig.ALARM_REQUEST_CODE, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        if (am != null) am.cancel(pi);
    }

    private void updateModeVisibility() {
        if (modeBButton.isChecked()) {
            modeAContainer.setVisibility(View.GONE);
            modeBContainer.setVisibility(View.VISIBLE);
        } else {
            modeAContainer.setVisibility(View.VISIBLE);
            modeBContainer.setVisibility(View.GONE);
        }
    }

    private TextView label(String s) { TextView t = new TextView(this); t.setText(s); t.setTextSize(15); return t; }
    private EditText input(String h) { EditText e = new EditText(this); e.setHint(h); e.setSingleLine(true); e.setInputType(InputType.TYPE_CLASS_NUMBER); return e; }
    private LinearLayout.LayoutParams lp(int bottom) { LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, -2); p.setMargins(0,0,0,dp(bottom)); return p; }
    private int parse(String s, int f) { try { int v = Integer.parseInt(s.trim()); return v > 0 ? v : f; } catch(Exception e) { return f; } }
    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private void requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.POST_NOTIFICATIONS}, 3001);
        }
    }
}
EOF

cat > app/src/main/java/com/example/automationassistant/AutomationForegroundService.java <<'EOF'
package com.example.automationassistant;

import android.app.*;
import android.content.*;
import android.os.*;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

public class AutomationForegroundService extends Service {
    private Handler handler;
    private Runnable loop;
    private SharedPreferences prefs;

    @Override public void onCreate() {
        super.onCreate();
        prefs = getSharedPreferences(AutomationConfig.PREF_NAME, MODE_PRIVATE);
        handler = new Handler(Looper.getMainLooper());
        createChannel();
        startForeground(AutomationConfig.NOTIFICATION_ID, new NotificationCompat.Builder(this, AutomationConfig.CHANNEL_ID)
                .setContentTitle("Automation Assistant Running")
                .setContentText("Foreground automation loop is active")
                .setSmallIcon(android.R.drawable.ic_menu_manage)
                .setOngoing(true)
                .build());
        loop = new Runnable() {
            @Override public void run() {
                if (!prefs.getBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, false)) { stopSelf(); return; }
                launchTarget();
                int open = prefs.getInt(AutomationConfig.KEY_OPEN_INTERVAL, 10);
                if (open <= 0) open = 10;
                handler.postDelayed(this, open * 60L * 1000L);
            }
        };
        handler.post(loop);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && AutomationConfig.ACTION_STOP_FOREGROUND.equals(intent.getAction())) {
            prefs.edit().putBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, false).apply();
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }
        prefs.edit().putBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, true).apply();
        return START_STICKY;
    }

    private void launchTarget() {
        Intent i = getPackageManager().getLaunchIntentForPackage(AutomationConfig.TARGET_PACKAGE);
        if (i != null) {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(i);
        }
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(AutomationConfig.CHANNEL_ID, "Automation Foreground Service", NotificationManager.IMPORTANCE_LOW);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }

    @Override public void onDestroy() {
        if (handler != null && loop != null) handler.removeCallbacks(loop);
        super.onDestroy();
    }

    @Nullable @Override public IBinder onBind(Intent intent) { return null; }
}
EOF

cat > app/src/main/java/com/example/automationassistant/AutomationAlarmReceiver.java <<'EOF'
package com.example.automationassistant;

import android.app.*;
import android.content.*;
import android.os.Build;
import androidx.core.content.ContextCompat;

public class AutomationAlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (intent == null || !AutomationConfig.ACTION_RUN_AUTOMATION.equals(intent.getAction())) return;
        SharedPreferences p = context.getSharedPreferences(AutomationConfig.PREF_NAME, Context.MODE_PRIVATE);
        if (!p.getBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, false)) return;
        Intent s = new Intent(context, AutomationForegroundService.class);
        s.setAction(AutomationConfig.ACTION_START_FOREGROUND);
        ContextCompat.startForegroundService(context, s);
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(AutomationConfig.TARGET_PACKAGE);
        if (launch != null) { launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP); context.startActivity(launch); }
        scheduleNext(context, p);
    }

    private void scheduleNext(Context c, SharedPreferences p) {
        int open = p.getInt(AutomationConfig.KEY_OPEN_INTERVAL, 10);
        if (open <= 0) open = 10;
        AlarmManager am = (AlarmManager)c.getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(c, AutomationAlarmReceiver.class);
        i.setAction(AutomationConfig.ACTION_RUN_AUTOMATION);
        PendingIntent pi = PendingIntent.getBroadcast(c, AutomationConfig.ALARM_REQUEST_CODE, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        if (am == null) return;
        long when = System.currentTimeMillis() + open * 60L * 1000L;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) am.set(AlarmManager.RTC_WAKEUP, when, pi);
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pi);
        else am.setExact(AlarmManager.RTC_WAKEUP, when, pi);
    }
}
EOF

cat > app/src/main/java/com/example/automationassistant/BootReceiver.java <<'EOF'
package com.example.automationassistant;

import android.content.*;
import androidx.core.content.ContextCompat;

public class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        SharedPreferences p = context.getSharedPreferences(AutomationConfig.PREF_NAME, Context.MODE_PRIVATE);
        if (p.getBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, false)) {
            Intent s = new Intent(context, AutomationForegroundService.class);
            s.setAction(AutomationConfig.ACTION_START_FOREGROUND);
            ContextCompat.startForegroundService(context, s);
        }
    }
}
EOF

cat > app/src/main/java/com/example/automationassistant/MyAutomationService.java <<'EOF'
package com.example.automationassistant;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.*;
import android.graphics.Path;
import android.graphics.Rect;
import android.os.*;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.*;
import java.util.regex.*;

public class MyAutomationService extends AccessibilityService {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private SharedPreferences prefs;
    private long lastRunAt = 0, lastTimeCollectAt = 0;
    private boolean heartRunning = false, percentRunning = false, secretRunning = false;

    private final Runnable heartRunnable = new Runnable() {
        @Override public void run() {
            if (!heartRunning) return;
            AccessibilityNodeInfo root = getRootInActiveWindow();
            if (root == null) { heartRunning = false; return; }
            AccessibilityNodeInfo n = findText(root, "克服心魔");
            if (n == null) { heartRunning = false; recycle(root); return; }
            clickNode(n); recycle(n); recycle(root);
            handler.postDelayed(this, 100);
        }
    };

    private final BroadcastReceiver timeReceiver = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent i) { checkSecret(); }
    };

    @Override protected void onServiceConnected() {
        super.onServiceConnected();
        prefs = getSharedPreferences(AutomationConfig.PREF_NAME, MODE_PRIVATE);
        IntentFilter f = new IntentFilter();
        f.addAction(Intent.ACTION_TIME_TICK);
        f.addAction(Intent.ACTION_TIME_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(timeReceiver, f, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(timeReceiver, f);
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null || event.getPackageName() == null) return;
        if (!AutomationConfig.TARGET_PACKAGE.contentEquals(event.getPackageName())) return;
        prefs = getSharedPreferences(AutomationConfig.PREF_NAME, MODE_PRIVATE);
        if (!prefs.getBoolean(AutomationConfig.KEY_AUTOMATION_ENABLED, false)) return;

        handleHeart();
        long now = System.currentTimeMillis();
        if (now - lastRunAt < 1000) return;
        lastRunAt = now;

        tap(950, 2100);

        String mode = prefs.getString(AutomationConfig.KEY_MODE, AutomationConfig.MODE_TIME);
        if (AutomationConfig.MODE_PERCENT.equals(mode)) {
            checkPercent();
        } else {
            int ci = prefs.getInt(AutomationConfig.KEY_COLLECT_INTERVAL, 300);
            if (ci <= 0) ci = 300;
            if (now - lastTimeCollectAt >= ci * 1000L) {
                lastTimeCollectAt = now;
                handler.postDelayed(this::collectEnergy, 800);
            }
        }
        checkSecret();
    }

    private void handleHeart() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return;
        AccessibilityNodeInfo d = findText(root, "心魔扰乱");
        if (d != null) { clickNode(d); recycle(d); }
        AccessibilityNodeInfo k = findText(root, "克服心魔");
        if (k != null) {
            clickNode(k); recycle(k);
            if (!heartRunning) { heartRunning = true; handler.postDelayed(heartRunnable, 100); }
        }
        recycle(root);
    }

    private void checkPercent() {
        if (percentRunning) return;
        percentRunning = true;
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) { percentRunning = false; return; }
        AccessibilityNodeInfo clock = findAny(root, "闹钟");
        if (clock == null) clock = findAny(root, "时钟");
        if (clock != null) { clickNode(clock); recycle(clock); } else tap(850,1500);
        recycle(root);

        handler.postDelayed(() -> {
            AccessibilityNodeInfo r = getRootInActiveWindow();
            if (r == null) { percentRunning = false; return; }
            AccessibilityNodeInfo title = findText(r, "修为结晶");
            if (title == null) { clickConfirm(r); recycle(r); percentRunning = false; return; }
            recycle(title);
            int value = extractPercent(r);
            int min = prefs.getInt(AutomationConfig.KEY_PERCENT_MIN,20);
            int max = prefs.getInt(AutomationConfig.KEY_PERCENT_MAX,40);
            if (min > max) { int t = min; min = max; max = t; }
            boolean ok = value >= min && value <= max;
            clickConfirm(r); recycle(r);
            if (ok) handler.postDelayed(() -> { collectEnergy(); percentRunning=false; }, 600);
            else percentRunning=false;
        }, 1500);
    }

    private void collectEnergy() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root != null) {
            List<AccessibilityNodeInfo> list = new ArrayList<>();
            findAll(root, "能量圈", list);
            if (!list.isEmpty()) {
                long delay=0;
                for (AccessibilityNodeInfo n:list) {
                    AccessibilityNodeInfo c=AccessibilityNodeInfo.obtain(n);
                    handler.postDelayed(() -> { clickNode(c); recycle(c); }, delay);
                    delay += 200;
                }
                handler.postDelayed(() -> { AccessibilityNodeInfo lr=getRootInActiveWindow(); if(lr!=null){ clickConfirm(lr); recycle(lr);} }, delay+300);
                for (AccessibilityNodeInfo n:list) recycle(n);
                recycle(root);
                return;
            }
            clickConfirm(root);
            recycle(root);
        }
        tap(300,1000);
        handler.postDelayed(() -> tap(700,1000),200);
        handler.postDelayed(() -> tap(500,1200),400);
    }

    private void checkSecret() {
        if (secretRunning) return;
        Calendar c = Calendar.getInstance();
        int h=c.get(Calendar.HOUR_OF_DAY), m=c.get(Calendar.MINUTE);
        if (h < 10 || h > 23 || m > 2) return;
        secretRunning = true;
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) { secretRunning=false; return; }
        AccessibilityNodeInfo s = findAny(root, "秘境");
        AccessibilityNodeInfo e = findAny(root, "进入秘境");
        if (s != null) { clickNode(s); recycle(s); handler.postDelayed(() -> { AccessibilityNodeInfo r=getRootInActiveWindow(); if(r!=null){ AccessibilityNodeInfo en=findAny(r,"进入秘境"); if(en!=null){clickNode(en); recycle(en);} recycle(r);} handler.postDelayed(() -> secretRunning=false,5000); }, 1000); }
        else if (e != null) { clickNode(e); recycle(e); handler.postDelayed(() -> secretRunning=false,5000); }
        else secretRunning=false;
        recycle(root);
    }

    private AccessibilityNodeInfo findText(AccessibilityNodeInfo r, String t) {
        if (r == null) return null;
        CharSequence s=r.getText();
        if (s != null && t.contentEquals(s)) return AccessibilityNodeInfo.obtain(r);
        for(int i=0;i<r.getChildCount();i++){ AccessibilityNodeInfo ch=r.getChild(i); if(ch==null) continue; AccessibilityNodeInfo res=findText(ch,t); recycle(ch); if(res!=null) return res; }
        return null;
    }

    private AccessibilityNodeInfo findAny(AccessibilityNodeInfo r,String t) {
        if (r == null) return null;
        if (contains(r.getText(),t)||contains(r.getContentDescription(),t)||contains(r.getViewIdResourceName(),t)) return AccessibilityNodeInfo.obtain(r);
        for(int i=0;i<r.getChildCount();i++){ AccessibilityNodeInfo ch=r.getChild(i); if(ch==null) continue; AccessibilityNodeInfo res=findAny(ch,t); recycle(ch); if(res!=null) return res; }
        return null;
    }

    private void findAll(AccessibilityNodeInfo r,String t,List<AccessibilityNodeInfo> out) {
        if (r == null) return;
        if (contains(r.getText(),t)||contains(r.getContentDescription(),t)||contains(r.getViewIdResourceName(),t)) out.add(AccessibilityNodeInfo.obtain(r));
        for(int i=0;i<r.getChildCount();i++){ AccessibilityNodeInfo ch=r.getChild(i); if(ch==null) continue; findAll(ch,t,out); recycle(ch); }
    }

    private int extractPercent(AccessibilityNodeInfo r) {
        List<String> texts = new ArrayList<>();
        collectTexts(r,texts);
        Pattern p=Pattern.compile("(\\d{1,3})\\s*%");
        for(String s:texts){ Matcher m=p.matcher(s); if(m.find()) try { return Integer.parseInt(m.group(1)); } catch(Exception ignored){} }
        return -1;
    }

    private void collectTexts(AccessibilityNodeInfo r,List<String> out) {
        if(r==null)return;
        if(r.getText()!=null) out.add(r.getText().toString());
        if(r.getContentDescription()!=null) out.add(r.getContentDescription().toString());
        for(int i=0;i<r.getChildCount();i++){ AccessibilityNodeInfo ch=r.getChild(i); if(ch==null) continue; collectTexts(ch,out); recycle(ch); }
    }

    private boolean clickConfirm(AccessibilityNodeInfo r) {
        AccessibilityNodeInfo n=findAny(r,"我知道了");
        if(n==null)n=findAny(r,"知道了");
        if(n==null)n=findAny(r,"确定");
        if(n!=null){ boolean ok=clickNode(n); recycle(n); return ok; }
        return false;
    }

    private boolean clickNode(AccessibilityNodeInfo n) {
        if(n==null)return false;
        AccessibilityNodeInfo c=AccessibilityNodeInfo.obtain(n);
        while(c!=null){
            if(c.isClickable()){
                boolean ok=c.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                recycle(c);
                if(ok)return true;
                break;
            }
            AccessibilityNodeInfo p=c.getParent(); recycle(c); c=p;
        }
        Rect b=new Rect(); n.getBoundsInScreen(b);
        return !b.isEmpty() && tap(b.centerX(),b.centerY());
    }

    private boolean tap(int x,int y) {
        if(Build.VERSION.SDK_INT < 24)return false;
        Path p=new Path(); p.moveTo(x,y);
        GestureDescription g=new GestureDescription.Builder().addStroke(new GestureDescription.StrokeDescription(p,0,80)).build();
        return dispatchGesture(g,null,null);
    }

    private boolean contains(CharSequence s,String t){ return s!=null && t!=null && s.toString().toLowerCase().contains(t.toLowerCase()); }
    private void recycle(AccessibilityNodeInfo n){ if(n!=null) try{n.recycle();}catch(Exception ignored){} }

    @Override public void onInterrupt() { heartRunning=false; percentRunning=false; secretRunning=false; handler.removeCallbacksAndMessages(null); }
    @Override public void onDestroy() { try{unregisterReceiver(timeReceiver);}catch(Exception ignored){} onInterrupt(); super.onDestroy(); }
}
EOF

echo "Project files created."
echo "Run: ./gradlew assembleDebug"
