package com.AndFlmsg;

import android.app.Application;
import android.os.Build;
import android.os.Environment;
import android.os.Process;
import android.util.Log;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;

/**
 * Application entry point.
 *
 * <p>Installs a local-only crash logger. Crash reports are written to the
 * app-specific external Documents directory when available so they can be
 * retrieved via USB/MTP or a file manager where Android permits access; if
 * external storage is unavailable, the app-private files directory is used.
 * Nothing is sent off the device.</p>
 *
 * <p>Only JVM uncaught exceptions are captured. Native crashes and ANRs are
 * not recorded by this handler.</p>
 */
public class AndFlmsgApplication extends Application {

    private static final String TAG = "AndFlmsg";
    private static final String CRASH_DIR = "crash-logs";
    private static final int MAX_CRASH_LOGS = 10;
    private static final Object PRUNE_LOCK = new Object();

    @Override
    public void onCreate() {
        super.onCreate();

        final Thread.UncaughtExceptionHandler previous =
                Thread.getDefaultUncaughtExceptionHandler();

        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) -> {
            try {
                writeCrashLog(thread, throwable);
            } finally {
                if (previous != null) {
                    previous.uncaughtException(thread, throwable);
                } else {
                    Process.killProcess(Process.myPid());
                }
            }
        });
    }

    private void writeCrashLog(Thread thread, Throwable throwable) {
        PrintWriter writer = null;
        File logFile = null;
        try {
            File dir = getCrashLogDir();
            if (dir == null) {
                Log.e(TAG, "Could not create crash log directory");
                return;
            }

            Date now = new Date();
            String timestamp = new SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US)
                    .format(now);
            logFile = createLogFile(dir, timestamp);

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
            if (writer.checkError()) {
                Log.e(TAG, "Failed to write crash log: " + logFile);
            }

            synchronized (PRUNE_LOCK) {
                pruneOldLogs(dir);
            }
        } catch (Throwable t) {
            Log.e(TAG, "Failed to write crash log"
                    + (logFile != null ? ": " + logFile : ""), t);
        } finally {
            if (writer != null) {
                writer.close();
            }
        }
    }

    private File getCrashLogDir() {
        File base = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS);
        if (base == null) {
            base = getFilesDir();
        }
        if (base == null) {
            return null;
        }

        File dir = new File(base, CRASH_DIR);
        if (!dir.exists() && !dir.mkdirs()) {
            return null;
        }
        return dir;
    }

    private File createLogFile(File dir, String timestamp) throws IOException {
        File logFile = new File(dir, "crash-" + timestamp + ".txt");
        int suffix = 1;
        while (!logFile.createNewFile()) {
            logFile = new File(dir, "crash-" + timestamp + "-" + suffix + ".txt");
            suffix++;
        }
        return logFile;
    }

    private void pruneOldLogs(File dir) {
        File[] logs = dir.listFiles((d, name) ->
                name.startsWith("crash-") && name.endsWith(".txt"));
        if (logs == null || logs.length <= MAX_CRASH_LOGS) {
            return;
        }

        Arrays.sort(logs, (first, second) ->
                first.getName().compareTo(second.getName()));
        int deleteCount = logs.length - MAX_CRASH_LOGS;
        for (int i = 0; i < deleteCount; i++) {
            if (!logs[i].delete()) {
                Log.w(TAG, "Could not delete old crash log: " + logs[i]);
            }
        }
    }
}
