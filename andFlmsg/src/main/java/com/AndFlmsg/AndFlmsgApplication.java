package com.AndFlmsg;

import android.app.Application;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;

/**
 * Application entry point.
 *
 * <p>Installs a local-only crash logger. Crash reports are written to the
 * app's private files directory and are never sent off the device.</p>
 */
public class AndFlmsgApplication extends Application {

    private static final String TAG = "AndFlmsg";
    private static final String CRASH_DIR = "crash-logs";
    private static final int MAX_CRASH_LOGS = 10;

    @Override
    public void onCreate() {
        super.onCreate();

        final Thread.UncaughtExceptionHandler previous =
                Thread.getDefaultUncaughtExceptionHandler();

        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) -> {
            writeCrashLog(thread, throwable);
            if (previous != null) {
                previous.uncaughtException(thread, throwable);
            } else {
                Process.killProcess(Process.myPid());
            }
        });
    }

    private void writeCrashLog(Thread thread, Throwable throwable) {
        PrintWriter writer = null;
        try {
            File dir = new File(getFilesDir(), CRASH_DIR);
            if (!dir.exists() && !dir.mkdirs()) {
                Log.e(TAG, "Could not create crash log directory");
                return;
            }

            Date now = new Date();
            String timestamp = new SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US)
                    .format(now);
            File logFile = new File(dir, "crash-" + timestamp + ".txt");

            writer = new PrintWriter(new FileWriter(logFile, false));
            writer.println("Time: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss Z", Locale.US)
                    .format(now));
            writer.println("App: " + BuildConfig.APPLICATION_ID + " "
                    + BuildConfig.VERSION_NAME + " (" + BuildConfig.VERSION_CODE + ")");
            writer.println("Android: " + Build.VERSION.RELEASE
                    + " (SDK " + Build.VERSION.SDK_INT + ")");
            writer.println("Device: " + Build.MANUFACTURER + " " + Build.MODEL);
            writer.println("Thread: " + thread.getName());
            writer.println();
            throwable.printStackTrace(writer);
            writer.flush();

            pruneOldLogs(dir);
        } catch (Throwable t) {
            Log.e(TAG, "Failed to write crash log", t);
        } finally {
            if (writer != null) {
                writer.close();
            }
        }
    }

    private void pruneOldLogs(File dir) {
        File[] logs = dir.listFiles((d, name) ->
                name.startsWith("crash-") && name.endsWith(".txt"));
        if (logs == null || logs.length <= MAX_CRASH_LOGS) {
            return;
        }

        Arrays.sort(logs, (first, second) ->
                Long.compare(first.lastModified(), second.lastModified()));
        int deleteCount = logs.length - MAX_CRASH_LOGS;
        for (int i = 0; i < deleteCount; i++) {
            if (!logs[i].delete()) {
                Log.w(TAG, "Could not delete old crash log: " + logs[i]);
            }
        }
    }
}
