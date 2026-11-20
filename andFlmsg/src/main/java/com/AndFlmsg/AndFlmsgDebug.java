/*
 * This is the error reporting section based on Google's ACRA documentation.
 * It allows the sending of an email, under user's control and review, to the 
 * author of the application with stack trace and Logcat information for 
 * debugging purposes.
 */

package com.AndFlmsg;

//error reporting

import org.acra.*;
import org.acra.annotation.*;

import android.app.Application;


@ReportsCrashes(formKey = "",
        mailTo = "vk2eta@gmail.com",
        customReportContent = {ReportField.ANDROID_VERSION, ReportField.PHONE_MODEL, ReportField.CUSTOM_DATA, ReportField.STACK_TRACE, ReportField.LOGCAT},
        mode = ReportingInteractionMode.TOAST,
        // forceCloseDialogAfterToast is optional and defaults to false.
        forceCloseDialogAfterToast = true)


public class AndFlmsgDebug extends Application {


    @Override
    public void onCreate() {
        // Initialization of ACRA error reporting
        super.onCreate();
        // AGP 8 generates non-final resource IDs, so R.string values cannot be
        // used in the @ReportsCrashes annotation. Configure the toast at runtime.
        // TODO: ACRA 4.5 is EOL; migrate to a supported version.
        ACRAConfiguration config = ACRA.getNewDefaultConfig(this);
        config.setResToastText(R.string.txt_crash_toast_text);
        ACRA.setConfig(config);
        ACRA.init(this);
    }

}
