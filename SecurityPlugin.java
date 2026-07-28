package com.capmaster2023.admincalculator;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import android.webkit.CookieManager;
import android.webkit.WebStorage;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKeys;
import java.io.File;
import java.security.MessageDigest;

@CapacitorPlugin(name = "Security")
public class SecurityPlugin extends Plugin {
    private static final String PREFS = "security_state_v1";
    private static final String KEY_FAILS = "master_failures";
    private static final int MAX_FAILS = 3;
    private static final String EXPECTED_RELEASE_CERT_SHA256 = "";

    @PluginMethod
    public void recordFailedMasterPassword(PluginCall call) {
        try {
            SharedPreferences p = securePrefs();
            int attempts = p.getInt(KEY_FAILS, 0) + 1;
            boolean wiped = false;
            if (attempts >= MAX_FAILS) {
                performFullWipe(getContext());
                attempts = 0;
                wiped = true;
            }
            p.edit().putInt(KEY_FAILS, attempts).apply();
            JSObject ret = new JSObject();
            ret.put("attempts", attempts);
            ret.put("remaining", Math.max(0, MAX_FAILS - attempts));
            ret.put("wiped", wiped);
            call.resolve(ret);
        } catch (Exception e) { call.reject("SECURITY_FAIL_COUNTER_ERROR", e); }
    }

    @PluginMethod
    public void resetMasterPasswordAttempts(PluginCall call) {
        try {
            securePrefs().edit().putInt(KEY_FAILS, 0).apply();
            JSObject ret = new JSObject(); ret.put("ok", true); call.resolve(ret);
        } catch (Exception e) { call.reject("SECURITY_FAIL_RESET_ERROR", e); }
    }

    @PluginMethod
    public void secureWipeAll(PluginCall call) {
        try {
            performFullWipe(getContext());
            securePrefs().edit().putInt(KEY_FAILS, 0).apply();
            JSObject ret = new JSObject(); ret.put("wiped", true); call.resolve(ret);
        } catch (Exception e) { call.reject("SECURITY_WIPE_ERROR", e); }
    }

    @PluginMethod
    public void isDeviceCompromised(PluginCall call) {
        try {
            boolean rooted = isRooted();
            boolean tampered = isTampered();
            JSObject ret = new JSObject();
            ret.put("rooted", rooted);
            ret.put("tampered", tampered);
            ret.put("compromised", rooted || tampered);
            ret.put("tamperCheckConfigured", EXPECTED_RELEASE_CERT_SHA256.trim().length() > 0);
            call.resolve(ret);
        } catch (Exception e) { call.reject("SECURITY_ENV_CHECK_ERROR", e); }
    }

    private SharedPreferences securePrefs() throws Exception {
        String keyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC);
        return EncryptedSharedPreferences.create(
            PREFS,
            keyAlias,
            getContext(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        );
    }

    public static void performFullWipe(Context c) {
        try { Downloads.get().cancelAll(); } catch (Exception ignored) {}
        try { VaultStore.secureDeleteRecursive(new File(c.getCacheDir(), "native_video")); } catch (Exception ignored) {}
        try { VaultStore.secureDeleteRecursive(new File(c.getCacheDir(), "dl_tmp")); } catch (Exception ignored) {}
        try { VaultStore.secureWipe(c, "main"); } catch (Exception ignored) {}
        try { VaultStore.secureWipe(c, "secondary"); } catch (Exception ignored) {}
        try { VaultStore.secureDeleteRecursive(new File(c.getFilesDir(), "vault")); } catch (Exception ignored) {}
        try { clearSensitiveSharedPreferences(c); } catch (Exception ignored) {}
        try { WebStorage.getInstance().deleteAllData(); } catch (Exception ignored) {}
        try { CookieManager.getInstance().removeAllCookies(null); CookieManager.getInstance().flush(); } catch (Exception ignored) {}
        try { VaultStore.secureDeleteRecursive(new File(c.getApplicationInfo().dataDir, "app_webview/Default/Local Storage")); } catch (Exception ignored) {}
        try { VaultStore.secureDeleteRecursive(new File(c.getApplicationInfo().dataDir, "app_webview/Default/IndexedDB")); } catch (Exception ignored) {}
        try { VaultStore.secureDeleteRecursive(new File(c.getApplicationInfo().dataDir, "databases")); } catch (Exception ignored) {}
    }

    private static void clearSensitiveSharedPreferences(Context c) {
        File spDir = new File(c.getApplicationInfo().dataDir, "shared_prefs");
        File[] files = spDir.listFiles();
        if (files == null) return;
        for (File f : files) {
            String n = f.getName().toLowerCase();
            if (n.contains("security") || n.contains("vault") || n.contains("secret") || n.contains("calendar_date_codes") || n.contains("capacitor")) {
                VaultStore.secureDeleteRecursive(f);
            }
        }
    }

    private boolean isRooted() {
        String tags = Build.TAGS;
        if (tags != null && tags.contains("test-keys")) return true;
        String[] paths = new String[] {
            "/system/app/Superuser.apk", "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/data/local/su", "/su/bin/su", "/system/bin/.ext/.su", "/system/usr/we-need-root/su",
            "/sbin/.magisk", "/data/adb/magisk", "/cache/magisk.log"
        };
        for (String p : paths) { try { if (new File(p).exists()) return true; } catch (Exception ignored) {} }
        try {
            Process proc = Runtime.getRuntime().exec(new String[]{"/system/xbin/which", "su"});
            int code = proc.waitFor();
            if (code == 0) return true;
        } catch (Exception ignored) {}
        return false;
    }

    private boolean isTampered() {
        String expected = EXPECTED_RELEASE_CERT_SHA256.replace(":", "").trim().toUpperCase();
        if (expected.length() == 0) return false;
        String actual = signingCertSha256().replace(":", "").trim().toUpperCase();
        return actual.length() > 0 && !expected.equals(actual);
    }

    private String signingCertSha256() {
        try {
            PackageManager pm = getContext().getPackageManager();
            PackageInfo info;
            Signature[] signatures;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info = pm.getPackageInfo(getContext().getPackageName(), PackageManager.GET_SIGNING_CERTIFICATES);
                signatures = info.signingInfo.hasMultipleSigners() ? info.signingInfo.getApkContentsSigners() : info.signingInfo.getSigningCertificateHistory();
            } else {
                info = pm.getPackageInfo(getContext().getPackageName(), PackageManager.GET_SIGNATURES);
                signatures = info.signatures;
            }
            if (signatures == null || signatures.length == 0) return "";
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(signatures[0].toByteArray());
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02X", b));
            return sb.toString();
        } catch (Exception e) { return ""; }
    }
}