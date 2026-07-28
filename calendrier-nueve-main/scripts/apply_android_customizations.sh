#!/usr/bin/env bash
set -e
APP=android/app/src/main
APP_ID=$(node -e "const c=require('./capacitor.config.json'); console.log(c.appId||'com.capmaster2023.calculatrice')")
APP_NAME=$(node -e "const c=require('./capacitor.config.json'); console.log(c.appName||'Calculatrice')")
APP_ID_PATH=$(printf '%s' "$APP_ID" | tr '.' '/')
# ===== Nom de l'app =====
mkdir -p "$APP/res/values"
cat > "$APP/res/values/strings.xml" <<EOF
<resources>
    <string name="app_name">$APP_NAME</string>
    <string name="title_activity_main">$APP_NAME</string>
    <string name="package_name">$APP_ID</string>
    <string name="custom_url_scheme">$APP_ID</string>
</resources>
EOF
# ===== Icônes (calculatrice) =====
# IMPORTANT : sur Android 8+ (API 26), Capacitor génère des icônes ADAPTATIVES
# dans mipmap-anydpi-v26/ qui REMPLACENT les PNG. C'est pour ça que l'icône
# bleue Capacitor par défaut s'affichait malgré les PNG copiés.
# On installe ici une icône adaptative complète (premier plan + fond) + les
# PNG legacy, et on supprime les anciennes icônes adaptatives de Capacitor.
mkdir -p "$APP/res/mipmap-mdpi" "$APP/res/mipmap-hdpi" "$APP/res/mipmap-xhdpi" "$APP/res/mipmap-xxhdpi" "$APP/res/mipmap-xxxhdpi" "$APP/res/mipmap-anydpi-v26"

# Legacy (Android 7 et moins) : icône composée carrée + ronde
cp android-res/ic_launcher-mdpi.png      "$APP/res/mipmap-mdpi/ic_launcher.png"
cp android-res/ic_launcher_round-mdpi.png "$APP/res/mipmap-mdpi/ic_launcher_round.png"
cp android-res/ic_launcher-hdpi.png      "$APP/res/mipmap-hdpi/ic_launcher.png"
cp android-res/ic_launcher_round-hdpi.png "$APP/res/mipmap-hdpi/ic_launcher_round.png"
cp android-res/ic_launcher-xhdpi.png      "$APP/res/mipmap-xhdpi/ic_launcher.png"
cp android-res/ic_launcher_round-xhdpi.png "$APP/res/mipmap-xhdpi/ic_launcher_round.png"
cp android-res/ic_launcher-xxhdpi.png      "$APP/res/mipmap-xxhdpi/ic_launcher.png"
cp android-res/ic_launcher_round-xxhdpi.png "$APP/res/mipmap-xxhdpi/ic_launcher_round.png"
cp android-res/ic_launcher-xxxhdpi.png      "$APP/res/mipmap-xxxhdpi/ic_launcher.png"
cp android-res/ic_launcher_round-xxxhdpi.png "$APP/res/mipmap-xxxhdpi/ic_launcher_round.png"

# Adaptatif (Android 8+) : couches premier plan + fond
cp android-res/ic_launcher_foreground-mdpi.png   "$APP/res/mipmap-mdpi/ic_launcher_foreground.png"
cp android-res/ic_launcher_background-mdpi.png   "$APP/res/mipmap-mdpi/ic_launcher_background.png"
cp android-res/ic_launcher_foreground-hdpi.png   "$APP/res/mipmap-hdpi/ic_launcher_foreground.png"
cp android-res/ic_launcher_background-hdpi.png   "$APP/res/mipmap-hdpi/ic_launcher_background.png"
cp android-res/ic_launcher_foreground-xhdpi.png  "$APP/res/mipmap-xhdpi/ic_launcher_foreground.png"
cp android-res/ic_launcher_background-xhdpi.png  "$APP/res/mipmap-xhdpi/ic_launcher_background.png"
cp android-res/ic_launcher_foreground-xxhdpi.png "$APP/res/mipmap-xxhdpi/ic_launcher_foreground.png"
cp android-res/ic_launcher_background-xxhdpi.png "$APP/res/mipmap-xxhdpi/ic_launcher_background.png"
cp android-res/ic_launcher_foreground-xxxhdpi.png "$APP/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
cp android-res/ic_launcher_background-xxxhdpi.png "$APP/res/mipmap-xxxhdpi/ic_launcher_background.png"

# On écrase les XML adaptatifs de Capacitor pour pointer vers NOS couches.
cat > "$APP/res/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF
cat > "$APP/res/mipmap-anydpi-v26/ic_launcher_round.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
EOF

# On retire toute référence Capacitor à un fond/premier-plan vectoriel par
# défaut (ic_launcher_background.xml / ic_launcher_foreground.xml + couleur),
# sinon le fond bleu Capacitor reprendrait le dessus.
rm -f "$APP/res/drawable/ic_launcher_background.xml" \
      "$APP/res/drawable-v24/ic_launcher_foreground.xml" \
      "$APP/res/values/ic_launcher_background.xml" 2>/dev/null || true
# Supprime la couleur ic_launcher_background si Capacitor l'a déclarée en colors.xml
if [ -f "$APP/res/values/colors.xml" ]; then
  python3 - "$APP/res/values/colors.xml" <<'PYCOL'
import sys, re
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
t = re.sub(r'\s*<color name="ic_launcher_background">[^<]*</color>', '', t)
open(p, "w", encoding="utf-8").write(t)
PYCOL
fi

# ===== Manifest : permissions + flags =====
python3 - <<'PY2'
from pathlib import Path
import re
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()

perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.CAMERA',
    'android.permission.RECORD_AUDIO',
]
block=''
for perm in perms:
    if 'android:name="%s"'%perm not in s:
        block += '<uses-permission android:name="%s" />\n    '%perm
if block:
    s=s.replace('<application', block+'<application', 1)

def ensure_app_attr(s, attr, value):
    if (attr + '=') in s:
        return re.sub(attr + r'="[^"]*"', attr + '="' + value + '"', s, count=1)
    return s.replace('<application', '<application ' + attr + '="' + value + '"', 1)

s = ensure_app_attr(s, 'android:allowBackup', 'false')
s = ensure_app_attr(s, 'android:usesCleartextTraffic', 'false')

p.write_text(s)
PY2

PKG_DIR="$APP/java/$APP_ID_PATH"
mkdir -p "$PKG_DIR"

# ===== NativeVideoPlugin : lecture native via ExoPlayer (depuis morceaux IndexedDB) =====
cat > "$PKG_DIR/NativeVideoPlugin.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.util.Base64;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@CapacitorPlugin(name = "NativeVideo")
public class NativeVideoPlugin extends Plugin {
    private final Map<String, File> sessions = new HashMap<>();

    @PluginMethod
    public void wipeNativeCache(PluginCall call) {
        try {
            File dir = new File(getContext().getCacheDir(), "native_video");
            deleteRecursive(dir);
            sessions.clear();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    private void deleteRecursive(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) for (File c : children) deleteRecursive(c);
        }
        try { f.delete(); } catch (Exception ignored) {}
    }

    @PluginMethod
    public void startSession(PluginCall call) {
        try {
            String name = call.getString("name", "video");
            String safe = name.replaceAll("[^a-zA-Z0-9._-]", "_");
            if (!safe.contains(".")) safe += ".mp4";
            String id = UUID.randomUUID().toString();
            File dir = new File(getContext().getCacheDir(), "native_video");
            if (!dir.exists()) dir.mkdirs();
            File file = new File(dir, id + "_" + safe);
            sessions.put(id, file);
            JSObject ret = new JSObject();
            ret.put("sessionId", id);
            call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void appendChunk(PluginCall call) {
        try {
            String id = call.getString("sessionId");
            String b64 = call.getString("base64");
            File file = sessions.get(id);
            if (file == null) { call.reject("Session vidéo introuvable"); return; }
            byte[] data = Base64.decode(b64, Base64.DEFAULT);
            FileOutputStream out = new FileOutputStream(file, true);
            out.write(data);
            out.close();
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void finishThumbnail(PluginCall call) {
        File file = null;
        MediaMetadataRetriever retriever = null;
        try {
            String id = call.getString("sessionId");
            file = sessions.remove(id);
            if (file == null || !file.exists()) { call.reject("Fichier vidéo introuvable"); return; }
            retriever = new MediaMetadataRetriever();
            retriever.setDataSource(file.getAbsolutePath());
            String d = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            long durationMs = 0;
            try { durationMs = Long.parseLong(d == null ? "0" : d); } catch (Exception ignored) {}
            long timeUs = durationMs > 0 ? (durationMs * 1000L / 2L) : 1000000L;
            Bitmap bmp = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            if (bmp == null) bmp = retriever.getFrameAtTime(1000000L, MediaMetadataRetriever.OPTION_CLOSEST);
            if (bmp == null) { call.reject("Preview vidéo impossible"); return; }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            bmp.compress(Bitmap.CompressFormat.JPEG, 78, out);
            JSObject ret = new JSObject();
            ret.put("thumbnail", Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP));
            call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
        finally {
            try { if (retriever != null) retriever.release(); } catch (Exception ignored) {}
            try { if (file != null) file.delete(); } catch (Exception ignored) {}
        }
    }

    @PluginMethod
    public void finishAndPlay(PluginCall call) {
        try {
            String id = call.getString("sessionId");
            String title = call.getString("title", "Vidéo");
            File file = sessions.remove(id);
            if (file == null || !file.exists()) { call.reject("Fichier vidéo introuvable"); return; }
            Intent intent = new Intent(getContext(), NativeVideoActivity.class);
            intent.putExtra("path", file.getAbsolutePath());
            intent.putExtra("title", title);
            LockControlPlugin.suspended = true;
            getActivity().startActivity(intent);
            call.resolve();
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }
}
EOFJAVA

cat > "$PKG_DIR/NativeVideoActivity.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.view.ViewGroup;
import android.view.WindowManager;
import androidx.media3.common.MediaItem;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;
import java.io.File;

public class NativeVideoActivity extends Activity {
    private ExoPlayer player;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
        String path = getIntent().getStringExtra("path");
        PlayerView playerView = new PlayerView(this);
        playerView.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        setContentView(playerView);
        player = new ExoPlayer.Builder(this).build();
        playerView.setPlayer(player);
        player.setMediaItem(MediaItem.fromUri(Uri.fromFile(new File(path))));
        player.prepare();
        player.play();
    }

    @Override protected void onStop() { super.onStop(); if (player != null) player.pause(); }
    @Override protected void onDestroy() { if (player != null) { player.release(); player = null; } super.onDestroy(); }
}
EOFJAVA

# ===== LockControl : pilote le verrouillage automatique (sections C/D) =====
cat > "$PKG_DIR/LockControlPlugin.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.webkit.WebView;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "LockControl")
public class LockControlPlugin extends Plugin {
    // Partagé avec MainActivity.onPause/onStop : true => ne pas re-verrouiller.
    // On utilise aussi une fenêtre de temps, parce qu'une permission Android déclenche onPause/onResume.
    public static volatile boolean suspended = false;
    public static volatile long suspendedUntil = 0L;
    // true => au prochain onResume de MainActivity, forcer l'ecran calculatrice.
    public static volatile boolean lockOnResume = false;

    public static boolean isSuspended() {
        return suspended || System.currentTimeMillis() < suspendedUntil;
    }

    public static void suspendForPermissions() {
        suspended = true;
        suspendedUntil = System.currentTimeMillis() + 120000L; // 2 minutes pour les popups permissions
    }

    @PluginMethod
    public void suspend(PluginCall call) { suspendForPermissions(); call.resolve(); }

    @PluginMethod
    public void resume(PluginCall call) { suspended = false; suspendedUntil = 0L; call.resolve(); }

    @PluginMethod
    public void lockNow(PluginCall call) {
        suspended = false; suspendedUntil = 0L;
        final WebView wv = (getBridge() != null) ? getBridge().getWebView() : null;
        if (wv != null) {
            wv.post(() -> {
                try { wv.evaluateJavascript("location.replace('index.html')", null); } catch (Exception ignored) {}
            });
        }
        call.resolve();
    }
}
EOFJAVA

# ===== Vault : ouverture du navigateur + listing/lecture/suppression des vidéos du coffre =====
cat > "$PKG_DIR/VaultPlugin.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.content.Intent;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;

@CapacitorPlugin(name = "Vault")
public class VaultPlugin extends Plugin {

    @PluginMethod
    public void openBrowser(PluginCall call) {
        try {
            LockControlPlugin.suspended = true;            // C : on ouvre une autre activité -> ne pas verrouiller
            Intent i = new Intent(getContext(), BrowserActivity.class);
            i.putExtra("vault", VaultStore.cleanVault(call.getString("vault", "main")));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) { LockControlPlugin.suspended = false; call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void openDownloads(PluginCall call) {
        try {
            LockControlPlugin.suspended = true;
            Intent i = new Intent(getContext(), DownloadsActivity.class);
            i.putExtra("vault", VaultStore.cleanVault(call.getString("vault", "main")));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) { LockControlPlugin.suspended = false; call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void listVaultVideos(PluginCall call) {
        try {
            String vault = VaultStore.cleanVault(call.getString("vault", "main"));
            JSONArray arr = VaultStore.list(getContext(), vault);
            JSObject ret = new JSObject();
            ret.put("items", arr);
            call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void playVaultVideo(PluginCall call) {
        try {
            String id = call.getString("id");
            String vault = VaultStore.cleanVault(call.getString("vault", "main"));
            JSONObject it = VaultStore.find(getContext(), vault, id);
            if (it == null) { call.reject("Vidéo introuvable"); return; }
            String path = it.optString("path", "");
            if (path.isEmpty() || !new File(path).exists()) { call.reject("Fichier introuvable"); return; }
            LockControlPlugin.suspended = true;
            Intent i = new Intent(getContext(), NativeVideoActivity.class);
            i.putExtra("path", path);
            i.putExtra("title", it.optString("name", "Vidéo"));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
            call.resolve();
        } catch (Exception e) { LockControlPlugin.suspended = false; call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void deleteVaultVideo(PluginCall call) {
        try { VaultStore.delete(getContext(), VaultStore.cleanVault(call.getString("vault", "main")), call.getString("id")); call.resolve(); }
        catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void wipeVault(PluginCall call) {
        try { VaultStore.wipe(getContext(), VaultStore.cleanVault(call.getString("vault", "main"))); call.resolve(); }
        catch (Exception e) { call.reject(e.getMessage(), e); }
    }
}
EOFJAVA

# ===== VaultStore : index JSON des vidéos téléchargées (fichiers privés de l'app) =====
cat > "$PKG_DIR/VaultStore.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.content.Context;
import android.util.Base64;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.RandomAccessFile;
import java.security.SecureRandom;
import org.json.JSONArray;
import org.json.JSONObject;

public class VaultStore {
    private static final SecureRandom RNG = new SecureRandom();

    static String cleanVault(String v) { return "secondary".equals(v) ? "secondary" : "main"; }
    static File dir(Context c) { return dir(c, "main"); }
    static File dir(Context c, String vault) {
        File root = new File(c.getFilesDir(), "vaults"); if (!root.exists()) root.mkdirs();
        File d = new File(root, cleanVault(vault)); if (!d.exists()) d.mkdirs(); return d;
    }
    static File thumbsDir(Context c) { return thumbsDir(c, "main"); }
    static File thumbsDir(Context c, String vault) {
        File d = new File(dir(c, vault), "thumbs"); if (!d.exists()) d.mkdirs(); return d;
    }
    static File indexFile(Context c) { return indexFile(c, "main"); }
    static File indexFile(Context c, String vault) { return new File(dir(c, vault), "index.json"); }

    static void migrateLegacyMain(Context c) {
        try {
            File oldDir = new File(c.getFilesDir(), "vault");
            File oldIndex = new File(oldDir, "index.json");
            File newIndex = indexFile(c, "main");
            if (oldIndex.exists() && !newIndex.exists()) {
                FileInputStream in = new FileInputStream(oldIndex);
                byte[] b = new byte[(int) oldIndex.length()]; int r = in.read(b); in.close();
                FileOutputStream out = new FileOutputStream(newIndex); out.write(b, 0, Math.max(0, r)); out.close();
            }
        } catch (Exception ignored) {}
    }

    static synchronized JSONArray readIndex(Context c) { return readIndex(c, "main"); }
    static synchronized JSONArray readIndex(Context c, String vault) {
        try {
            migrateLegacyMain(c);
            File f = indexFile(c, vault);
            if (!f.exists()) return new JSONArray();
            FileInputStream in = new FileInputStream(f);
            byte[] b = new byte[(int) f.length()];
            int r = in.read(b); in.close();
            String s = new String(b, 0, Math.max(0, r), "UTF-8");
            if (s.trim().isEmpty()) return new JSONArray();
            return new JSONArray(s);
        } catch (Exception e) { return new JSONArray(); }
    }
    static synchronized void writeIndex(Context c, JSONArray a) { writeIndex(c, "main", a); }
    static synchronized void writeIndex(Context c, String vault, JSONArray a) {
        try { FileOutputStream o = new FileOutputStream(indexFile(c, vault)); o.write(a.toString().getBytes("UTF-8")); o.close(); }
        catch (Exception ignored) {}
    }

    static synchronized void add(Context c, JSONObject entry) { add(c, "main", entry); }
    static synchronized void add(Context c, String vault, JSONObject entry) {
        try { entry.put("vault", cleanVault(vault)); } catch (Exception ignored) {}
        JSONArray a = readIndex(c, vault); a.put(entry); writeIndex(c, vault, a);
    }

    static synchronized void updateThumb(Context c, String vault, String id, String thumbPath) {
        try {
            JSONArray a = readIndex(c, vault);
            for (int i = 0; i < a.length(); i++) {
                JSONObject e = a.optJSONObject(i);
                if (e != null && id != null && id.equals(e.optString("id"))) { e.put("thumb", thumbPath); }
            }
            writeIndex(c, vault, a);
        } catch (Exception ignored) {}
    }

    static synchronized JSONArray list(Context c) { return list(c, "main"); }
    static synchronized JSONArray list(Context c, String vault) {
        JSONArray src = readIndex(c, vault); JSONArray out = new JSONArray();
        for (int i = src.length() - 1; i >= 0; i--) {
            try {
                JSONObject e = src.getJSONObject(i);
                JSONObject o = new JSONObject();
                o.put("id", e.optString("id"));
                o.put("name", e.optString("name"));
                o.put("type", e.optString("type", e.optString("mime", "video/mp4")));
                o.put("size", e.optLong("size", 0));
                o.put("vault", cleanVault(vault));
                String thumb = "";
                String tp = e.optString("thumb", "");
                if (!tp.isEmpty()) {
                    File tf = new File(tp);
                    if (tf.exists()) {
                        FileInputStream in = new FileInputStream(tf);
                        byte[] b = new byte[(int) tf.length()];
                        int r = in.read(b); in.close();
                        thumb = "data:image/jpeg;base64," + Base64.encodeToString(b, 0, Math.max(0, r), Base64.NO_WRAP);
                    }
                }
                o.put("thumb", thumb); out.put(o);
            } catch (Exception ignored) {}
        }
        return out;
    }

    static synchronized JSONObject find(Context c, String id) { return find(c, "main", id); }
    static synchronized JSONObject find(Context c, String vault, String id) {
        JSONArray a = readIndex(c, vault);
        for (int i = 0; i < a.length(); i++) {
            JSONObject e = a.optJSONObject(i);
            if (e != null && id != null && id.equals(e.optString("id"))) return e;
        }
        return null;
    }

    static synchronized void delete(Context c, String id) { delete(c, "main", id); }
    static synchronized void delete(Context c, String vault, String id) {
        JSONArray a = readIndex(c, vault); JSONArray n = new JSONArray();
        for (int i = 0; i < a.length(); i++) {
            JSONObject e = a.optJSONObject(i);
            if (e != null && id != null && id.equals(e.optString("id"))) {
                secureDeleteRecursive(new File(e.optString("path", "")));
                String t = e.optString("thumb", ""); if (!t.isEmpty()) secureDeleteRecursive(new File(t));
            } else if (e != null) { n.put(e); }
        }
        writeIndex(c, vault, n);
    }

    static synchronized void wipe(Context c) { wipe(c, "main"); }
    static synchronized void wipe(Context c, String vault) { secureWipe(c, vault); }

    static synchronized void secureWipe(Context c, String vault) {
        try {
            JSONArray a = readIndex(c, vault);
            for (int i = 0; i < a.length(); i++) {
                JSONObject e = a.optJSONObject(i); if (e == null) continue;
                secureDeleteRecursive(new File(e.optString("path", "")));
                String t = e.optString("thumb", ""); if (!t.isEmpty()) secureDeleteRecursive(new File(t));
            }
            secureDeleteRecursive(indexFile(c, vault));
            File d = dir(c, vault);
            secureDeleteRecursive(new File(d, "thumbs"));
            writeIndex(c, vault, new JSONArray());
        } catch (Exception ignored) {}
    }

    static void secureDeleteRecursive(File f) {
        if (f == null || !f.exists()) return;
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) for (File c : children) secureDeleteRecursive(c);
            try { f.delete(); } catch (Exception ignored) {}
            return;
        }
        overwriteFile(f);
        try { f.delete(); } catch (Exception ignored) {}
    }

    private static void overwriteFile(File f) {
        RandomAccessFile raf = null;
        try {
            long len = f.length();
            if (len <= 0) return;
            raf = new RandomAccessFile(f, "rws");
            byte[] buf = new byte[8192];
            for (int pass = 0; pass < 3; pass++) {
                raf.seek(0);
                long left = len;
                while (left > 0) {
                    int n = (int)Math.min(buf.length, left);
                    RNG.nextBytes(buf);
                    raf.write(buf, 0, n);
                    left -= n;
                }
                raf.getFD().sync();
            }
        } catch (Exception ignored) {}
        finally { try { if (raf != null) raf.close(); } catch (Exception ignored) {} }
    }
}
EOFJAVA

# ===== Hls : analyse des playlists m3u8 (master + media, clé AES, init fMP4) =====
cat > "$PKG_DIR/Hls.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import java.util.ArrayList;
import java.util.List;

public class Hls {
    public static class Variant { public String url; public long bandwidth; public int height; public String resolution = ""; }
    public static class Seg { public String url; public double dur; }
    public static class Media {
        public List<Seg> segs = new ArrayList<>();
        public String keyMethod = "NONE"; public String keyUri = null; public String keyIvHex = null;
        public String mapUri = null;
        public double totalDur = 0;
        public boolean isFmp4 = false;
    }

    static String resolve(String base, String ref) {
        if (ref == null) return null;
        ref = ref.trim();
        if (ref.startsWith("http://") || ref.startsWith("https://")) return ref;
        try { return new java.net.URL(new java.net.URL(base), ref).toString(); } catch (Exception e) { return ref; }
    }

    public static boolean isMaster(String text) { return text.contains("#EXT-X-STREAM-INF"); }

    public static List<Variant> parseMaster(String text, String baseUrl) {
        List<Variant> out = new ArrayList<>();
        String[] lines = text.split("\\r?\\n");
        for (int i = 0; i < lines.length; i++) {
            String ln = lines[i].trim();
            if (ln.startsWith("#EXT-X-STREAM-INF")) {
                Variant v = new Variant();
                String attrs = ln.substring(ln.indexOf(':') + 1);
                v.bandwidth = parseLongAttr(attrs, "BANDWIDTH");
                String res = parseStrAttr(attrs, "RESOLUTION");
                if (res != null) {
                    v.resolution = res;
                    try { v.height = Integer.parseInt(res.substring(res.indexOf('x') + 1)); } catch (Exception ignored) {}
                }
                for (int j = i + 1; j < lines.length; j++) {
                    String u = lines[j].trim();
                    if (u.isEmpty() || u.startsWith("#")) continue;
                    v.url = resolve(baseUrl, u); i = j; break;
                }
                if (v.url != null) out.add(v);
            }
        }
        return out;
    }

    public static Media parseMedia(String text, String baseUrl) {
        Media m = new Media();
        String[] lines = text.split("\\r?\\n");
        double nextDur = 0;
        for (int i = 0; i < lines.length; i++) {
            String ln = lines[i].trim();
            if (ln.startsWith("#EXT-X-KEY")) {
                String attrs = ln.substring(ln.indexOf(':') + 1);
                String method = parseStrAttr(attrs, "METHOD"); if (method != null) m.keyMethod = method;
                String uri = parseStrAttr(attrs, "URI"); if (uri != null) m.keyUri = resolve(baseUrl, uri);
                String iv = parseStrAttr(attrs, "IV"); if (iv != null) m.keyIvHex = iv;
            } else if (ln.startsWith("#EXT-X-MAP")) {
                String attrs = ln.substring(ln.indexOf(':') + 1);
                String uri = parseStrAttr(attrs, "URI"); if (uri != null) { m.mapUri = resolve(baseUrl, uri); m.isFmp4 = true; }
            } else if (ln.startsWith("#EXTINF")) {
                try {
                    String d = ln.substring(ln.indexOf(':') + 1);
                    int comma = d.indexOf(','); if (comma >= 0) d = d.substring(0, comma);
                    nextDur = Double.parseDouble(d.trim());
                } catch (Exception e) { nextDur = 0; }
            } else if (!ln.isEmpty() && !ln.startsWith("#")) {
                Seg s = new Seg(); s.url = resolve(baseUrl, ln); s.dur = nextDur;
                m.segs.add(s); m.totalDur += nextDur; nextDur = 0;
                if (ln.contains(".m4s")) m.isFmp4 = true;
            }
        }
        return m;
    }

    static long parseLongAttr(String attrs, String key) {
        try { String v = parseRaw(attrs, key); if (v == null) return 0; return Long.parseLong(v.replaceAll("[^0-9]", "")); }
        catch (Exception e) { return 0; }
    }
    static String parseStrAttr(String attrs, String key) {
        String v = parseRaw(attrs, key); if (v == null) return null;
        v = v.trim();
        if (v.startsWith("\"") && v.endsWith("\"") && v.length() >= 2) v = v.substring(1, v.length() - 1);
        return v;
    }
    static String parseRaw(String attrs, String key) {
        int idx = attrs.indexOf(key + "=");
        if (idx < 0) return null;
        int start = idx + key.length() + 1; boolean q = false; StringBuilder sb = new StringBuilder();
        for (int i = start; i < attrs.length(); i++) {
            char ch = attrs.charAt(i);
            if (ch == '"') { q = !q; sb.append(ch); continue; }
            if (ch == ',' && !q) break;
            sb.append(ch);
        }
        return sb.toString();
    }
}
EOFJAVA
echo "Partie 1 écrite."

# ===== Downloads : moteur (HLS+AES-128 / MP4 direct), file d'attente, pause/reprise/annulation =====
cat > "$PKG_DIR/Downloads.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.media.ThumbnailUtils;
import android.os.Build;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public class Downloads {
    public static final int QUEUED = 0, RUNNING = 1, PAUSED = 2, DONE = 3, ERROR = 4, CANCELED = 5;

    public static class Task {
        public String id, url, name, type = "video/mp4", referer, ua, cookie;
        public String vault = "main";
        public boolean hls = false;
        public volatile int state = QUEUED;
        public volatile long total = 0, done = 0;   // octets
        public volatile long speed = 0;             // octets/s
        public volatile int segTotal = 0, segDone = 0;
        public volatile String error = null;
        public File tmp;
        public volatile boolean pauseReq = false, cancelReq = false;
        public long createdAt = System.currentTimeMillis();
    }

    private static Downloads I;
    public static synchronized Downloads get() { if (I == null) I = new Downloads(); return I; }

    private final LinkedHashMap<String, Task> tasks = new LinkedHashMap<>();
    private final ExecutorService exec = Executors.newFixedThreadPool(2);
    private Context app;

    public synchronized List<Task> snapshot() { return new ArrayList<>(tasks.values()); }
    public synchronized Task getTask(String id) { return tasks.get(id); }

    public synchronized String enqueue(Context ctx, String url, String name, String type, boolean hls,
                                       String referer, String ua, String cookie) {
        return enqueue(ctx, url, name, type, hls, referer, ua, cookie, "main");
    }

    public synchronized String enqueue(Context ctx, String url, String name, String type, boolean hls,
                                       String referer, String ua, String cookie, String vault) {
        app = ctx.getApplicationContext();
        final Task t = new Task();
        t.id = "dl_" + System.currentTimeMillis() + "_" + Math.abs(url.hashCode());
        t.url = url; t.name = sanitize(name); t.hls = hls; t.referer = referer; t.ua = ua; t.cookie = cookie;
        if (type != null && !type.isEmpty()) t.type = type;
        t.vault = VaultStore.cleanVault(vault);
        tasks.put(t.id, t);
        startService();
        exec.submit(() -> run(t));
        return t.id;
    }

    public synchronized void pause(String id) {
        Task t = tasks.get(id);
        if (t != null && (t.state == RUNNING || t.state == QUEUED)) t.pauseReq = true;
    }
    public synchronized void resume(String id) {
        final Task t = tasks.get(id);
        if (t != null && (t.state == PAUSED || t.state == ERROR)) {
            t.pauseReq = false; t.cancelReq = false; t.error = null; t.state = QUEUED;
            startService();
            exec.submit(() -> run(t));
        }
    }
    public synchronized void cancel(String id) {
        Task t = tasks.get(id);
        if (t != null) { t.cancelReq = true; if (t.state == PAUSED || t.state == ERROR || t.state == QUEUED) finalizeCancel(t); }
    }
    public synchronized void remove(String id) {
        Task t = tasks.get(id);
        if (t != null) { t.cancelReq = true; finalizeCancel(t); tasks.remove(id); }
    }

    public synchronized void cancelAll() {
        for (Task t : new ArrayList<>(tasks.values())) {
            try { t.cancelReq = true; finalizeCancel(t); } catch (Exception ignored) {}
        }
        tasks.clear();
    }

    private void finalizeCancel(Task t) {
        t.state = CANCELED;
        try { if (t.tmp != null && t.tmp.exists()) t.tmp.delete(); } catch (Exception ignored) {}
    }

    private void startService() {
        // Notifications supprimées : pas de service foreground pour les téléchargements.
        // Les tâches continuent via l'exécuteur interne tant que l'application reste active.
    }

    public synchronized boolean hasActive() {
        for (Task t : tasks.values()) if (t.state == RUNNING || t.state == QUEUED) return true;
        return false;
    }

    // Analyse de playlist pour le sélecteur de qualité (utilise seulement les en-têtes du Task)
    public String probeText(String url, Task t) throws IOException { return fetchText(t, url); }

    // ---- moteur ----
    private void run(Task t) {
        if (t.cancelReq) { finalizeCancel(t); return; }
        t.state = RUNNING; t.error = null;
        try {
            File dlDir = new File(app.getCacheDir(), "dl_tmp"); if (!dlDir.exists()) dlDir.mkdirs();
            if (t.hls) runHls(t, dlDir); else runDirect(t, dlDir);
            if (t.cancelReq) { finalizeCancel(t); return; }
            complete(t);
        } catch (PausedException pe) {
            t.state = PAUSED; t.speed = 0;
        } catch (CanceledException ce) {
            finalizeCancel(t);
        } catch (Exception e) {
            t.state = ERROR; t.speed = 0; t.error = (e.getMessage() == null ? e.toString() : e.getMessage());
        }
    }

    static class PausedException extends Exception {}
    static class CanceledException extends Exception {}

    private void checkControl(Task t) throws PausedException, CanceledException {
        if (t.cancelReq) throw new CanceledException();
        if (t.pauseReq) throw new PausedException();
    }

    private HttpURLConnection open(Task t, String urlStr, long rangeFrom) throws IOException {
        URL url = new URL(urlStr);
        HttpURLConnection c = (HttpURLConnection) url.openConnection();
        c.setConnectTimeout(20000); c.setReadTimeout(30000);
        c.setInstanceFollowRedirects(true);
        if (t.ua != null) c.setRequestProperty("User-Agent", t.ua);
        if (t.referer != null) c.setRequestProperty("Referer", t.referer);
        if (t.cookie != null && !t.cookie.isEmpty()) c.setRequestProperty("Cookie", t.cookie);
        if (rangeFrom > 0) c.setRequestProperty("Range", "bytes=" + rangeFrom + "-");
        return c;
    }
    // Suit manuellement les redirections, y compris http<->https (que HttpURLConnection ne suit pas seul)
    private HttpURLConnection openFollow(Task t, String urlStr, long rangeFrom) throws IOException {
        String cur = urlStr;
        for (int i = 0; i < 6; i++) {
            HttpURLConnection c = open(t, cur, rangeFrom);
            int code = c.getResponseCode();
            if (code == 301 || code == 302 || code == 303 || code == 307 || code == 308) {
                String loc = c.getHeaderField("Location"); c.disconnect();
                if (loc == null) return open(t, cur, rangeFrom);
                cur = Hls.resolve(cur, loc); continue;
            }
            return c;
        }
        return open(t, cur, rangeFrom);
    }

    private String fetchText(Task t, String url) throws IOException {
        HttpURLConnection c = openFollow(t, url, 0);
        InputStream in = c.getInputStream();
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        byte[] b = new byte[8192]; int r;
        while ((r = in.read(b)) != -1) bo.write(b, 0, r);
        in.close(); c.disconnect();
        return new String(bo.toByteArray(), "UTF-8");
    }
    private byte[] fetchBytes(Task t, String url) throws IOException {
        HttpURLConnection c = openFollow(t, url, 0);
        InputStream in = c.getInputStream();
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        byte[] b = new byte[8192]; int r;
        while ((r = in.read(b)) != -1) bo.write(b, 0, r);
        in.close(); c.disconnect();
        return bo.toByteArray();
    }

    private void runDirect(Task t, File dlDir) throws Exception {
        File out = new File(dlDir, t.id + ".part"); t.tmp = out;
        long from = out.exists() ? out.length() : 0;
        HttpURLConnection c = openFollow(t, t.url, from);
        int code = c.getResponseCode();
        boolean ranged = (code == 206);
        long len = c.getContentLengthLong();
        if (ranged && from > 0) t.total = from + (len > 0 ? len : 0);
        else { t.total = (len > 0 ? len : 0); }
        if (from > 0 && !ranged) { out.delete(); from = 0; }   // le serveur ignore Range -> repartir de zéro
        RandomAccessFile raf = new RandomAccessFile(out, "rw");
        raf.seek(from); t.done = from;
        InputStream in = c.getInputStream();
        byte[] buf = new byte[65536]; int r; long winBytes = 0; long winStart = System.currentTimeMillis();
        try {
            while ((r = in.read(buf)) != -1) {
                checkControl(t);
                raf.write(buf, 0, r); t.done += r; winBytes += r;
                long now = System.currentTimeMillis();
                if (now - winStart >= 600) { t.speed = (long) (winBytes * 1000.0 / (now - winStart)); winBytes = 0; winStart = now; }
            }
            t.speed = 0;
        } finally {
            try { in.close(); } catch (Exception ignored) {}
            try { raf.close(); } catch (Exception ignored) {}
            c.disconnect();
        }
    }

    private void runHls(Task t, File dlDir) throws Exception {
        String playlistUrl = t.url;
        String txt = fetchText(t, playlistUrl);
        if (Hls.isMaster(txt)) {
            List<Hls.Variant> vs = Hls.parseMaster(txt, playlistUrl);
            Hls.Variant best = null;
            for (Hls.Variant v : vs) if (best == null || v.bandwidth > best.bandwidth) best = v;
            if (best != null) { playlistUrl = best.url; txt = fetchText(t, playlistUrl); }
        }
        Hls.Media m = Hls.parseMedia(txt, playlistUrl);
        if (m.segs.isEmpty()) throw new IOException("Liste HLS vide ou illisible.");
        t.segTotal = m.segs.size();

        byte[] key = null;
        boolean enc = "AES-128".equalsIgnoreCase(m.keyMethod) && m.keyUri != null;
        if (enc) key = fetchBytes(t, m.keyUri);

        String ext = m.isFmp4 ? "mp4" : "ts";
        t.type = m.isFmp4 ? "video/mp4" : "video/mp2t";
        if (t.name == null || t.name.isEmpty()) t.name = "video";
        if (!t.name.contains(".")) t.name = t.name + "." + ext;

        File out = new File(dlDir, t.id + ".part"); t.tmp = out;
        File idx = new File(dlDir, t.id + ".idx");
        int startSeg = 0;
        if (out.exists() && idx.exists()) {
            try { startSeg = Integer.parseInt(readAll(idx).trim()); } catch (Exception e) { startSeg = 0; }
            if (startSeg < 0 || startSeg > m.segs.size()) { startSeg = 0; out.delete(); }
        } else { out.delete(); }

        FileOutputStream fo = new FileOutputStream(out, startSeg > 0);
        long winBytes = 0; long winStart = System.currentTimeMillis();
        try {
            if (startSeg == 0 && m.mapUri != null) {
                byte[] init = fetchBytes(t, m.mapUri); fo.write(init); t.done += init.length;
            }
            for (int i = startSeg; i < m.segs.size(); i++) {
                checkControl(t);
                Hls.Seg s = m.segs.get(i);
                byte[] data = fetchBytes(t, s.url);
                if (enc) { byte[] iv = ivForSegment(m.keyIvHex, i); data = aesDecrypt(key, iv, data); }
                fo.write(data); t.done += data.length; winBytes += data.length; t.segDone = i + 1;
                if (i + 1 > 0) t.total = (long) ((double) t.done / (i + 1) * m.segs.size());
                long now = System.currentTimeMillis();
                if (now - winStart >= 600) { t.speed = (long) (winBytes * 1000.0 / (now - winStart)); winBytes = 0; winStart = now; }
                writeAll(idx, String.valueOf(i + 1));
            }
            t.speed = 0;
        } finally { try { fo.close(); } catch (Exception ignored) {} }
        idx.delete();
    }

    private byte[] ivForSegment(String ivHex, int seq) {
        if (ivHex != null) {
            String h = (ivHex.startsWith("0x") || ivHex.startsWith("0X")) ? ivHex.substring(2) : ivHex;
            try {
                byte[] iv = new byte[16];
                for (int i = 0; i < 16; i++) {
                    int idx = h.length() - 32 + i * 2;
                    if (idx < 0) iv[i] = 0; else iv[i] = (byte) Integer.parseInt(h.substring(idx, idx + 2), 16);
                }
                return iv;
            } catch (Exception ignored) {}
        }
        byte[] iv = new byte[16];
        iv[15] = (byte) (seq & 0xff); iv[14] = (byte) ((seq >> 8) & 0xff);
        iv[13] = (byte) ((seq >> 16) & 0xff); iv[12] = (byte) ((seq >> 24) & 0xff);
        return iv;
    }
    private byte[] aesDecrypt(byte[] key, byte[] iv, byte[] data) throws Exception {
        Cipher ci = Cipher.getInstance("AES/CBC/PKCS5Padding");
        ci.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"), new IvParameterSpec(iv));
        return ci.doFinal(data);
    }

    private void complete(Task t) throws Exception {
        File vaultDir = VaultStore.dir(app, t.vault);
        String ext = t.name.contains(".") ? t.name.substring(t.name.lastIndexOf('.') + 1) : (t.hls ? "ts" : "mp4");
        File dst = new File(vaultDir, t.id + "." + ext);
        if (!t.tmp.renameTo(dst)) { copyFile(t.tmp, dst); t.tmp.delete(); }

        // On enregistre la vidéo SANS générer de miniature.
        // MediaMetadataRetriever plante au niveau natif (SIGSEGV non rattrapable) sur certaines vidéos,
        // ce qui tuait l'app à la fin du téléchargement. La galerie affiche ▶ + le nom quand il n'y a pas d'aperçu.
        JSONObject e = new JSONObject();
        e.put("id", t.id); e.put("name", t.name); e.put("type", t.type);
        e.put("size", dst.length()); e.put("path", dst.getAbsolutePath());
        e.put("thumb", ""); e.put("date", System.currentTimeMillis());
        VaultStore.add(app, t.vault, e);
        t.done = dst.length(); t.total = dst.length(); t.speed = 0; t.state = DONE;
    }

    static void copyFile(File a, File b) throws IOException {
        FileInputStream in = new FileInputStream(a); FileOutputStream out = new FileOutputStream(b);
        byte[] buf = new byte[65536]; int r; while ((r = in.read(buf)) != -1) out.write(buf, 0, r);
        in.close(); out.close();
    }
    static String readAll(File f) throws IOException {
        FileInputStream in = new FileInputStream(f); ByteArrayOutputStream bo = new ByteArrayOutputStream();
        byte[] b = new byte[4096]; int r; while ((r = in.read(b)) != -1) bo.write(b, 0, r); in.close();
        return new String(bo.toByteArray(), "UTF-8");
    }
    static void writeAll(File f, String s) {
        try { FileOutputStream o = new FileOutputStream(f); o.write(s.getBytes("UTF-8")); o.close(); } catch (Exception ignored) {}
    }

    static String sanitize(String n) {
        if (n == null || n.trim().isEmpty()) return "video";
        n = n.trim().replaceAll("[\\\\/:*?\"<>|]", "_");
        if (n.length() > 80) n = n.substring(0, 80);
        return n;
    }
}
EOFJAVA

# ===== DownloadService : service sans notification =====
cat > "$PKG_DIR/DownloadService.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import java.util.Locale;

public class DownloadService extends Service {
    @Override public IBinder onBind(Intent intent) { return null; }
    @Override public int onStartCommand(Intent intent, int flags, int startId) { stopSelf(); return START_NOT_STICKY; }
    public static String human(long bytes) {
        if (bytes < 1024) return bytes + " o";
        double k = bytes / 1024.0; if (k < 1024) return String.format(Locale.US, "%.0f Ko", k);
        double mb = k / 1024.0; if (mb < 1024) return String.format(Locale.US, "%.1f Mo", mb);
        return String.format(Locale.US, "%.2f Go", mb / 1024.0);
    }
}
EOFJAVA

# ===== DownloadsActivity : liste des téléchargements (progression, temps restant, vitesse, pause/play/suppr) =====
cat > "$PKG_DIR/DownloadsActivity.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import java.util.List;

public class DownloadsActivity extends Activity {
    private LinearLayout listLayout;
    private final Handler h = new Handler(Looper.getMainLooper());
    private Runnable poll;
    private String activeVault = "main";

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
        activeVault = VaultStore.cleanVault(getIntent() == null ? "main" : getIntent().getStringExtra("vault"));
        LinearLayout root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#0E1014"));
        LinearLayout bar = new LinearLayout(this); bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setPadding(dp(14), dp(28), dp(14), dp(12)); bar.setGravity(Gravity.CENTER_VERTICAL);
        Button back = pill("‹ Retour"); back.setOnClickListener(v -> finish());
        LinearLayout.LayoutParams blp = (LinearLayout.LayoutParams) back.getLayoutParams();
        blp.width = ViewGroup.LayoutParams.WRAP_CONTENT; blp.weight = 0f;
        TextView title = new TextView(this); title.setText("Téléchargements");
        title.setTextColor(Color.parseColor("#ECEEF3")); title.setTextSize(19); title.setPadding(dp(12), 0, 0, 0);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        title.setLayoutParams(tlp);
        bar.addView(back); bar.addView(title);
        root.addView(bar);
        ScrollView sc = new ScrollView(this);
        listLayout = new LinearLayout(this); listLayout.setOrientation(LinearLayout.VERTICAL);
        listLayout.setPadding(dp(12), 0, dp(12), dp(24));
        sc.addView(listLayout);
        root.addView(sc, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(root);
    }

    @Override protected void onResume() {
        super.onResume(); LockControlPlugin.suspended = true;
        poll = new Runnable() { @Override public void run() { render(); h.postDelayed(this, 800); } };
        h.post(poll);
    }
    @Override protected void onPause() { super.onPause(); if (poll != null) h.removeCallbacks(poll); }

    @Override public void onUserLeaveHint() {
        LockControlPlugin.suspended = false;
        LockControlPlugin.lockOnResume = true;
        super.onUserLeaveHint();
        finish();
    }

    private void render() {
        List<Downloads.Task> ts = Downloads.get().snapshot();
        listLayout.removeAllViews();
        ts.removeIf(t -> !activeVault.equals(VaultStore.cleanVault(t.vault)));
        if (ts.isEmpty()) {
            TextView e = new TextView(this);
            e.setText("Aucun téléchargement.\n\nOuvre le navigateur, va sur une page avec une vidéo, puis touche le bouton « Télécharger ».");
            e.setTextColor(Color.parseColor("#8B93A4")); e.setPadding(dp(8), dp(40), dp(8), 0);
            e.setGravity(Gravity.CENTER_HORIZONTAL); e.setTextSize(14);
            listLayout.addView(e); return;
        }
        for (Downloads.Task t : ts) listLayout.addView(card(t));
    }

    private View card(final Downloads.Task t) {
        LinearLayout c = new LinearLayout(this); c.setOrientation(LinearLayout.VERTICAL);
        c.setBackgroundColor(Color.parseColor("#161922")); c.setPadding(dp(14), dp(12), dp(14), dp(12));
        LinearLayout.LayoutParams clp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        clp.setMargins(0, 0, 0, dp(10)); c.setLayoutParams(clp);

        TextView nm = new TextView(this); nm.setText(t.name); nm.setTextColor(Color.parseColor("#ECEEF3"));
        nm.setTextSize(15); nm.setSingleLine(true); nm.setEllipsize(TextUtils.TruncateAt.MIDDLE);
        c.addView(nm);

        ProgressBar pb = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        pb.setMax(100);
        int pct = (t.total > 0) ? (int) Math.min(100, t.done * 100 / t.total) : (t.state == Downloads.DONE ? 100 : 0);
        pb.setProgress(pct);
        LinearLayout.LayoutParams plp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        plp.setMargins(0, dp(8), 0, dp(6)); pb.setLayoutParams(plp);
        c.addView(pb);

        TextView info = new TextView(this); info.setTextColor(Color.parseColor("#8B93A4")); info.setTextSize(12.5f);
        info.setText(infoLine(t, pct));
        c.addView(info);

        LinearLayout row = new LinearLayout(this); row.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams rlp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        rlp.setMargins(0, dp(10), 0, 0); row.setLayoutParams(rlp);
        if (t.state == Downloads.RUNNING || t.state == Downloads.QUEUED) {
            Button p = pill("⏸  Pause"); p.setOnClickListener(v -> Downloads.get().pause(t.id)); row.addView(p);
        } else if (t.state == Downloads.PAUSED || t.state == Downloads.ERROR) {
            Button r = pill("▶  Reprendre"); r.setOnClickListener(v -> Downloads.get().resume(t.id)); row.addView(r);
        }
        Button del = pill("🗑  Supprimer"); del.setOnClickListener(v -> { Downloads.get().remove(t.id); render(); }); row.addView(del);
        c.addView(row);
        return c;
    }

    private String infoLine(Downloads.Task t, int pct) {
        String st;
        switch (t.state) {
            case Downloads.RUNNING: st = "En cours"; break;
            case Downloads.QUEUED:  st = "En attente"; break;
            case Downloads.PAUSED:  st = "En pause"; break;
            case Downloads.DONE:    st = "Terminé · ajouté à la galerie"; break;
            case Downloads.ERROR:   st = "Erreur : " + (t.error == null ? "inconnue" : t.error); break;
            case Downloads.CANCELED:st = "Annulé"; break;
            default: st = "";
        }
        if (t.state == Downloads.RUNNING) {
            String size = (t.total > 0) ? (DownloadService.human(t.done) + " / " + DownloadService.human(t.total)) : DownloadService.human(t.done);
            String spd = DownloadService.human(t.speed) + "/s";
            String eta = "";
            if (t.speed > 0 && t.total > t.done) { long s = (t.total - t.done) / Math.max(1, t.speed); eta = " · reste " + fmtTime(s); }
            String seg = (t.hls && t.segTotal > 0) ? (" · seg " + t.segDone + "/" + t.segTotal) : "";
            return pct + "% · " + size + " · " + spd + eta + seg;
        }
        if (t.state == Downloads.DONE) return st + " · " + DownloadService.human(t.total);
        return st;
    }
    static String fmtTime(long s) {
        if (s < 60) return s + " s";
        long m = s / 60; long r = s % 60;
        if (m < 60) return m + " min " + r + " s";
        long hh = m / 60; long mm = m % 60; return hh + " h " + mm + " min";
    }

    private Button pill(String t) {
        Button b = new Button(this); b.setText(t); b.setAllCaps(false);
        b.setTextColor(Color.parseColor("#ECEEF3")); b.setBackgroundColor(Color.parseColor("#262B38")); b.setTextSize(13);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        lp.setMargins(0, 0, dp(8), 0); b.setLayoutParams(lp);
        return b;
    }
    private int dp(int v) { return (int) (v * getResources().getDisplayMetrics().density); }
}
EOFJAVA
echo "Partie 2 écrite."

# ===== BrowserActivity : navigateur intégré sécurisé + onglets + historique + détection vidéo =====
cat > "$PKG_DIR/BrowserActivity.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Message;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.JsPromptResult;
import android.webkit.JsResult;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

public class BrowserActivity extends Activity {
    private FrameLayout frame;
    private EditText urlBar;
    private Button fab;
    private TextView tabCount;
    private ProgressBar pageProgress;
    private LinearLayout root, topWrap, bottomBar;
    private FrameLayout pill;
    private final ArrayList<WebView> tabs = new ArrayList<>();
    private final ArrayList<String> tabTitles = new ArrayList<>();
    private int activeTab = -1;
    private final LinkedHashMap<String, String> media = new LinkedHashMap<>();
    private String playedUrl = null;
    private String pageTitle = "video";
    private String activeVault = "main";
    private SharedPreferences prefs;
    private boolean browserAlive = true;
    private int blockedCount = 0;
    private static final String PREF = "private_browser_v2";
    private static final String DUCK_HOME = "https://duckduckgo.com/";
    private static final String CLEAN_DDG_HOME =
        "<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1\">" +
        "<style>*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}html,body{margin:0;height:100%;background:#0f1111;color:#fff;font-family:Arial,sans-serif;overflow:hidden}" +
        ".wrap{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:28px;gap:24px;transform:translateY(-8vh)}" +
        ".logo{width:118px;height:118px;border-radius:50%;display:grid;place-items:center;background:#e95420;border:6px solid #fff;box-shadow:0 8px 28px rgba(0,0,0,.35);font-size:62px}" +
        ".name{font-size:42px;line-height:1;font-weight:400;letter-spacing:-1px;text-align:center}" +
        "form{width:min(630px,100%);display:flex;align-items:center;background:#3f4145;border-radius:18px;padding:0 12px;height:58px;box-shadow:0 6px 22px rgba(0,0,0,.25)}" +
        "input{flex:1;height:100%;border:0;outline:0;background:transparent;color:#fff;font-size:19px;padding:0 12px}input::placeholder{color:#b9b9b9}" +
        "button{border:0;background:transparent;color:#d8d8d8;font-size:28px;padding:8px 10px}" +
        "</style></head><body><div class=\"wrap\"><div class=\"logo\">🦆</div><div class=\"name\">DuckDuckGo</div>" +
        "<form action=\"https://duckduckgo.com/\" method=\"get\"><input name=\"q\" autofocus placeholder=\"Faites une recherche privée\" autocomplete=\"off\"><button type=\"submit\">⌕</button></form>" +
        "</div></body></html>";

    private String theme = "dark";       // dark | black
    private int accent = 0xFFFB542B;     // orange Brave
    private boolean adblockOn = true;
    private boolean allowCapture = false; // false = captures bloquées (FLAG_SECURE)

    private static final String INJECT_JS =
        "(function(){try{" +
        // --- masquage cosmetique des pubs ---
        "if(!window.__adcss){window.__adcss=1;var sel=['ins.adsbygoogle','.adsbygoogle','iframe[src*=\"ads\"]'," +
        "'iframe[src*=\"doubleclick\"]','iframe[src*=\"googlesyndication\"]','[id^=\"google_ads\"]'," +
        "'[id*=\"_ads_\"]','[class*=\"ad-banner\"]','[class*=\"adbanner\"]','.advertisement','[aria-label=\"Advertisement\"]'," +
        "'[class^=\"ad-\"]','[id^=\"ad-\"]','.popup-overlay','.popunder','[class*=\"sponsor\"]','[id*=\"sponsor\"]'," +
        "'[class*=\"promo\"]','[id*=\"promo\"]','[class*=\"banner\"]','[id*=\"banner\"]','[class*=\"modal-ad\"]'];" +
        "var st=document.createElement('style');st.innerHTML=sel.join(',')+'{display:none!important;visibility:hidden!important;height:0!important;max-height:0!important;overflow:hidden!important}';" +
        "(document.head||document.documentElement).appendChild(st);}" +
        "if(location.hostname.indexOf('duckduckgo.com')>-1&&!window.__ddgclean){window.__ddgclean=1;" +
        "var css='header,nav,footer,aside,[href*=\"duck.ai\"],[aria-label*=\"Duck.ai\"],[aria-label*=\"Menu\"],button[aria-label*=\"Menu\"],a[href*=\"play.google.com\"],[class*=\"download\"],[class*=\"tagline\"],[class*=\"privacy\"],[class*=\"settings\"],[data-testid*=\"duckai\"],[data-testid*=\"app\"],[data-testid*=\"badge\"]{display:none!important;visibility:hidden!important;height:0!important;max-height:0!important;overflow:hidden!important}';" +
        "var ds=document.createElement('style');ds.innerHTML=css;(document.head||document.documentElement).appendChild(ds);" +
        "setInterval(function(){try{document.querySelectorAll('a[href*=\"play.google.com\"],[href*=\"duck.ai\"],[aria-label*=\"Menu\"]').forEach(function(e){e.style.display='none';});}catch(e){}},800);}" +
        "}catch(e){}" +
        "try{" +
        // --- detection de la video reellement lancee par l'utilisateur ---
        "if(!window.__vdl){window.__vdl=1;var g=0;" +
        "['pointerdown','touchstart','mousedown','click','keydown'].forEach(function(e){try{document.addEventListener(e,function(){g=Date.now();},true);}catch(_){}});" +
        "function ui(){return (Date.now()-g)<2500;}" +
        "function rep(v){try{var s=v.currentSrc||v.src||'';if(window.AndroidVault&&AndroidVault.onUserPlay)AndroidVault.onUserPlay(String(s));}catch(e){}}" +
        "try{var op=HTMLMediaElement.prototype.play;HTMLMediaElement.prototype.play=function(){try{if(this.tagName==='VIDEO'&&ui())rep(this);}catch(e){}return op.apply(this,arguments);};}catch(e){}" +
        "try{document.addEventListener('playing',function(ev){var v=ev.target;if(v&&v.tagName==='VIDEO'&&ui())rep(v);},true);}catch(e){}}" +
        "}catch(e){}})();";

    // ===================== Bloqueur de pub / traqueurs / popups =====================
    private static final String[] AD_HOSTS = {
        "doubleclick.net","googlesyndication.com","googleadservices.com","google-analytics.com",
        "googletagservices.com","googletagmanager.com","pagead2.googlesyndication","adservice.google",
        "adnxs.com","adsystem.com","amazon-adsystem.com","adsrvr.org","rubiconproject.com","pubmatic.com",
        "openx.net","criteo.com","criteo.net","taboola.com","outbrain.com","exoclick.com","exosrv.com",
        "popads.net","popcash.net","propellerads.com","propellerpops","adsterra","adskeeper.com","mgid.com",
        "revcontent.com","zedo.com","smartadserver.com","yieldmo.com","sharethrough.com","teads.tv",
        "moatads.com","scorecardresearch.com","quantserve.com","adform.net","casalemedia.com","contextweb.com",
        "bidswitch.net","3lift.com","gumgum.com","districtm.io","sonobi.com","spotxchange.com","advertising.com",
        "adcolony.com","applovin.com","unityads","chartbeat.com","hotjar.com","onesignal.com","juicyads.com",
        "trafficjunky.com","trafficfactory","ad-maven","admaven","hilltopads","clickadu","onclickads","onclkds.com",
        "mellowads","clicksor","bidvertiser","ad.plus","adtng.com","poptm.com","mybetterdl","hmwebsec",
        "luckcasino","push-notification","pushwhy","pushvictim","clickaine","cpmstar","adkernel","admixer",
        "adspeed","servedby","adbutler","admaven.com","adblade","viglink","yllix","adhood","adhive",
        "popunder","pop-under","interstitial-ad","banner-ad","prebid","adroll","adsafeprotected",
        "ad-score","adscore","adtraffic","trafficstars","richmedia","rtmark",
        "cleaner-update","phone-cleaner","security-warning","virus-alert","device-scan",
        "system-repair","repair-now","nettoyer-maintenant","Votre-compte-risque",
        "mymobilesecurevpn","securevpn","mobile-secure-vpn","vpn-update","vpnsecure"
    };

    private boolean isBlockedAd(String url){
        if(!adblockOn || url==null) return false;
        String u = url.toLowerCase(Locale.US);
        if(!(u.startsWith("http://")||u.startsWith("https://"))) return false;
        for(String h : AD_HOSTS){ if(u.contains(h)) return true; }
        if(u.contains("/ads/")||u.contains("/adserver")||u.contains("/advert")||u.contains("/popunder")
           ||u.contains("/pop-under")||u.contains("=popunder")||u.contains("/ad-frame")||u.contains("/adframe")
           ||u.contains("doubleclick")||u.contains("/banner")||u.contains("/banners/")||u.contains("/sponsor")
           ||u.contains("clickid=")||u.contains("utm_medium=ad")||u.contains("utm_source=ad")
           ||u.contains("cleaner")||u.contains("antivirus")||u.contains("virus-alert")||u.contains("security-warning")
           ||u.contains("device-scan")||u.contains("repair-now")||u.contains("nettoyer-maintenant")
           ||u.contains("mymobilesecurevpn")||u.contains("securevpn")||u.contains("mobile-secure-vpn")) return true;
        return false;
    }
    private WebResourceResponse blockedResponse(){
        return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream(new byte[0]));
    }

    private boolean isCleanDuckHome(String url){
        if(url == null) return true;
        try {
            java.net.URL x = new java.net.URL(url);
            String h = x.getHost() == null ? "" : x.getHost().toLowerCase(Locale.US);
            String path = x.getPath() == null ? "" : x.getPath();
            String q = x.getQuery();
            return (h.equals("duckduckgo.com") || h.equals("www.duckduckgo.com")) && (path.isEmpty() || path.equals("/")) && (q == null || q.trim().isEmpty());
        } catch(Exception e) { return "https://duckduckgo.com/".equals(url) || "https://www.duckduckgo.com/".equals(url); }
    }

    private void loadCleanDuckHome(WebView w){
        if(w == null) return;
        urlBar.setText(DUCK_HOME);
        prefs.edit().putString("last_url", DUCK_HOME).putString("resume_url", DUCK_HOME).putBoolean("browser_open", true).apply();
        synchronized(media){ media.clear(); } playedUrl = null; updateFab();
        w.loadDataWithBaseURL(DUCK_HOME, CLEAN_DDG_HOME, "text/html", "UTF-8", DUCK_HOME);
    }

    private boolean looksAdDialog(String m){
        if(m == null) return false;
        String x = m.toLowerCase(Locale.US);
        return x.contains("vpn") || x.contains("mymobilesecure") || x.contains("installer") || x.contains("installation")
            || x.contains("mode sans échec") || x.contains("mode sans echec") || x.contains("continuer à regarder")
            || x.contains("virus") || x.contains("nettoyer") || x.contains("réparer") || x.contains("reparer")
            || x.contains("compte risque") || x.contains("appareil") || x.contains("bloqué") || x.contains("bloque");
    }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        LockControlPlugin.suspended = true;
        activeVault = VaultStore.cleanVault(getIntent() == null ? "main" : getIntent().getStringExtra("vault"));
        prefs = getSharedPreferences(PREF + "_" + activeVault, MODE_PRIVATE);
        theme = prefs.getString("theme", "dark");
        accent = prefs.getInt("accent", 0xFFFB542B);
        adblockOn = prefs.getBoolean("adblock", true);
        allowCapture = prefs.getBoolean("allow_capture", false);
        applyCaptureFlag();

        root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(cBg());

        // ----- barre d'adresse (pilule arrondie) -----
        topWrap = new LinearLayout(this); topWrap.setOrientation(LinearLayout.HORIZONTAL);
        topWrap.setGravity(Gravity.CENTER_VERTICAL);
        topWrap.setPadding(dp(10), dp(24), dp(10), dp(8));
        topWrap.setBackgroundColor(cBg());

        pill = new FrameLayout(this);
        pill.setBackground(gd(cPill(), 22));
        LinearLayout pillRow = new LinearLayout(this); pillRow.setOrientation(LinearLayout.HORIZONTAL);
        pillRow.setGravity(Gravity.CENTER_VERTICAL);
        pillRow.setPadding(dp(14), dp(7), dp(8), dp(7));
        TextView lead = new TextView(this); lead.setText("\uD83D\uDD12");
        lead.setTextColor(cMuted()); lead.setTextSize(13); lead.setPadding(0, 0, dp(8), 0);
        urlBar = new EditText(this);
        urlBar.setHint("Rechercher ou saisir une adresse");
        urlBar.setSingleLine(true); urlBar.setTextColor(cText()); urlBar.setHintTextColor(cMuted());
        urlBar.setBackgroundColor(Color.TRANSPARENT); urlBar.setPadding(0, dp(2), 0, dp(2)); urlBar.setTextSize(14.5f);
        urlBar.setInputType(InputType.TYPE_TEXT_VARIATION_URI); urlBar.setImeOptions(EditorInfo.IME_ACTION_GO);
        urlBar.setOnEditorActionListener((v, actionId, ev) -> {
            if (actionId == EditorInfo.IME_ACTION_GO || (ev != null && ev.getKeyCode() == KeyEvent.KEYCODE_ENTER)) { go(urlBar.getText().toString()); return true; }
            return false;
        });
        urlBar.setOnFocusChangeListener((v, has) -> { if (has) urlBar.selectAll(); });
        urlBar.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button reload = roundIcon("\u27F3"); reload.setOnClickListener(v -> { WebView w = current(); if (w != null) w.reload(); });
        pillRow.addView(lead); pillRow.addView(urlBar); pillRow.addView(reload);
        pill.addView(pillRow);
        pill.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        topWrap.addView(pill);
        root.addView(topWrap);

        // ----- progression -----
        pageProgress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        pageProgress.setMax(100); pageProgress.setProgress(0);
        tintProgress();
        pageProgress.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3)));
        pageProgress.setVisibility(View.GONE);
        root.addView(pageProgress);

        // ----- zone webview + bouton telecharger -----
        frame = new FrameLayout(this);
        fab = new Button(this); fab.setText("\u2913  Télécharger"); fab.setAllCaps(false);
        fab.setTextColor(0xFF1A1407); fab.setBackground(gd(accent, 26)); fab.setTextSize(14.5f);
        fab.setVisibility(View.GONE);
        FrameLayout.LayoutParams flp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        flp.gravity = Gravity.BOTTOM | Gravity.END; flp.setMargins(0, 0, dp(16), dp(18)); fab.setLayoutParams(flp);
        fab.setOnClickListener(v -> openSheet());
        frame.addView(fab);
        root.addView(frame, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        // ----- barre inferieure -----
        bottomBar = new LinearLayout(this); bottomBar.setOrientation(LinearLayout.HORIZONTAL);
        bottomBar.setGravity(Gravity.CENTER_VERTICAL); bottomBar.setBackgroundColor(cBg());
        bottomBar.setPadding(dp(6), dp(6), dp(6), dp(10));
        Button appHome = navIcon("\u25A6"); appHome.setOnClickListener(v -> { LockControlPlugin.suspended = true; finish(); });
        Button back = navIcon("\u2039"); back.setOnClickListener(v -> { WebView w = current(); if (w != null && w.canGoBack()) w.goBack(); });
        Button fwd  = navIcon("\u203A"); fwd.setOnClickListener(v -> { WebView w = current(); if (w != null && w.canGoForward()) w.goForward(); });
        Button home = navIcon("\u2302"); home.setOnClickListener(v -> go(DUCK_HOME));
        FrameLayout tabWrap = new FrameLayout(this);
        tabWrap.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        tabCount = new TextView(this); tabCount.setText("1"); tabCount.setTextColor(cText());
        tabCount.setTextSize(13); tabCount.setGravity(Gravity.CENTER);
        tabCount.setMinWidth(dp(26)); tabCount.setMinHeight(dp(26));
        tabCount.setPadding(dp(6), dp(3), dp(6), dp(3));
        tabCount.setBackground(gdStroke(Color.TRANSPARENT, 7, cText(), 2));
        FrameLayout.LayoutParams tcp = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        tcp.gravity = Gravity.CENTER; tabCount.setLayoutParams(tcp);
        tabWrap.addView(tabCount); tabWrap.setOnClickListener(v -> openTabsDialog());
        Button menu = navIcon("\u22EE"); menu.setOnClickListener(v -> openMenu());
        bottomBar.addView(appHome); bottomBar.addView(back); bottomBar.addView(fwd); bottomBar.addView(home); bottomBar.addView(tabWrap); bottomBar.addView(menu);
        root.addView(bottomBar);

        setContentView(root);
        String last = prefs.getString("last_url", DUCK_HOME);
        newTab(last, true);
    }

    private void tintProgress(){ try { if (pageProgress.getProgressDrawable()!=null) pageProgress.getProgressDrawable().setColorFilter(accent, PorterDuff.Mode.SRC_IN); } catch (Exception ignored) {} }

    // Capture d'écran / enregistrement vidéo : FLAG_SECURE bloque les deux quand allowCapture=false.
    private void applyCaptureFlag(){
        try {
            if (allowCapture) getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
            else getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
        } catch (Exception ignored) {}
    }

    // ===================== couleurs / theme =====================
    private int cBg()     { return "black".equals(theme) ? 0xFF000000 : 0xFF1B1B1F; }
    private int cPill()   { return "black".equals(theme) ? 0xFF17171C : 0xFF2E2E36; }
    private int cSurface(){ return "black".equals(theme) ? 0xFF111116 : 0xFF26262C; }
    private int cText()   { return 0xFFF2F3F7; }
    private int cMuted()  { return 0xFF9AA0AE; }
    private GradientDrawable gd(int color, int radiusDp) { GradientDrawable g = new GradientDrawable(); g.setColor(color); g.setCornerRadius(dp(radiusDp)); return g; }
    private GradientDrawable gdStroke(int color, int radiusDp, int stroke, int strokeDp) { GradientDrawable g = new GradientDrawable(); g.setColor(color); g.setCornerRadius(dp(radiusDp)); g.setStroke(dp(strokeDp), stroke); return g; }

    private void applyTheme() {
        try {
            if (root != null) root.setBackgroundColor(cBg());
            if (topWrap != null) topWrap.setBackgroundColor(cBg());
            if (bottomBar != null) bottomBar.setBackgroundColor(cBg());
            if (pill != null) pill.setBackground(gd(cPill(), 22));
            if (urlBar != null) { urlBar.setTextColor(cText()); urlBar.setHintTextColor(cMuted()); }
            if (fab != null) fab.setBackground(gd(accent, 26));
            if (tabCount != null) { tabCount.setTextColor(cText()); tabCount.setBackground(gdStroke(Color.TRANSPARENT, 7, cText(), 2)); }
            tintProgress();
        } catch (Exception ignored) {}
        prefs.edit().putString("theme", theme).putInt("accent", accent).putBoolean("adblock", adblockOn).apply();
    }

    private WebView current(){ if(activeTab>=0 && activeTab<tabs.size()) return tabs.get(activeTab); return null; }

    private WebView buildWebView(){
        WebView web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true); s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(true); // pas de lecture auto (pubs)
        s.setLoadWithOverviewMode(true); s.setUseWideViewPort(true); s.setBuiltInZoomControls(true); s.setDisplayZoomControls(false);
        s.setSupportMultipleWindows(true); s.setJavaScriptCanOpenWindowsAutomatically(false);
        if (Build.VERSION.SDK_INT >= 21) s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        CookieManager.getInstance().setAcceptCookie(true);
        if (Build.VERSION.SDK_INT >= 21) CookieManager.getInstance().setAcceptThirdPartyCookies(web, false);
        try { web.addJavascriptInterface(new VaultBridge(), "AndroidVault"); } catch (Exception ignored) {}
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req){
                String u = req == null || req.getUrl() == null ? "" : req.getUrl().toString();
                return guardUrl(view, u, req != null && req.isForMainFrame(), req != null && req.hasGesture());
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, String url){ return guardUrl(view, url, true, true); }
            @Override public void onPageStarted(WebView view, String url, Bitmap fav){
                urlBar.setText(url); prefs.edit().putString("last_url", url).putString("resume_url", url).putBoolean("browser_open", true).apply();
                synchronized(media){media.clear();} playedUrl = null; runOnUiThread(() -> updateFab());
                inject(view);
            }
            @Override public void onPageFinished(WebView view, String url){
                pageTitle = view.getTitle()!=null ? view.getTitle() : "video";
                int i=tabs.indexOf(view); if(i>=0) tabTitles.set(i, cleanTitle(pageTitle, url));
                if(view==current()) urlBar.setText(url);
                inject(view);
                saveHistory(cleanTitle(pageTitle,url), url); updateTabButton();
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req){
                try {
                    String u = req != null && req.getUrl()!=null ? req.getUrl().toString() : "";
                    if (isBlockedAd(u)) { blockedCount++; return blockedResponse(); }
                    inspect(u);
                } catch(Exception ignored){}
                return null;
            }
            @Override public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail){
                String restore = prefs == null ? "https://duckduckgo.com/" : prefs.getString("resume_url", prefs.getString("last_url", DUCK_HOME));
                try {
                    int idx = tabs.indexOf(view);
                    if (idx >= 0) { frame.removeView(view); tabs.remove(idx); tabTitles.remove(idx); try { view.destroy(); } catch(Exception ignored) {} if (activeTab >= tabs.size()) activeTab = tabs.size() - 1; }
                } catch(Exception ignored) {}
                toast("Page instable bloquée");
                new Handler(Looper.getMainLooper()).postDelayed(() -> { if (browserAlive) newTab(restore == null ? DUCK_HOME : restore, true); }, 250);
                return true;
            }
        });
        web.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onJsAlert(WebView view, String url, String message, JsResult result){
                if(looksAdDialog(message) || isBlockedAd(url)){ try{ result.confirm(); }catch(Exception ignored){} toast("Pub bloquée"); return true; }
                return false;
            }
            @Override public boolean onJsConfirm(WebView view, String url, String message, JsResult result){
                if(looksAdDialog(message) || isBlockedAd(url)){ try{ result.cancel(); }catch(Exception ignored){} toast("Pub bloquée"); return true; }
                return false;
            }
            @Override public boolean onJsPrompt(WebView view, String url, String message, String defaultValue, JsPromptResult result){
                if(looksAdDialog(message) || isBlockedAd(url)){ try{ result.cancel(); }catch(Exception ignored){} toast("Pub bloquée"); return true; }
                return false;
            }
            @Override public void onProgressChanged(WebView view, int p){
                if (view != current()) return;
                runOnUiThread(() -> {
                    if (pageProgress == null) return;
                    if (p < 100) { pageProgress.setVisibility(View.VISIBLE); pageProgress.setProgress(p); }
                    else { pageProgress.setProgress(100); pageProgress.postDelayed(() -> { if (pageProgress!=null) pageProgress.setVisibility(View.GONE); }, 180); }
                });
            }
            @Override public void onReceivedTitle(WebView view, String title){
                int i=tabs.indexOf(view); if(i>=0 && title!=null && !title.trim().isEmpty()) tabTitles.set(i, cleanTitle(title, view.getUrl()));
            }
            @Override public boolean onCreateWindow(WebView view, boolean dialog, boolean userGesture, Message resultMsg){
                // Bloque les popups : on n'ouvre jamais de nouvelle fenetre automatique.
                final WebView popup = new WebView(BrowserActivity.this);
                popup.getSettings().setJavaScriptEnabled(false);
                popup.setWebViewClient(new WebViewClient(){
                    @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest req){
                        String u=req==null||req.getUrl()==null?"":req.getUrl().toString(); return handlePopupUrl(v, u, userGesture);
                    }
                    @Override public boolean shouldOverrideUrlLoading(WebView v, String u){ return handlePopupUrl(v, u, userGesture); }
                    @Override public void onPageStarted(WebView v, String u, Bitmap fav){ handlePopupUrl(v, u, userGesture); try{v.stopLoading();}catch(Exception ignored){} }
                });
                WebView.WebViewTransport tr=(WebView.WebViewTransport)resultMsg.obj;
                tr.setWebView(popup);
                resultMsg.sendToTarget();
                if(!userGesture) toast("Popup bloqué");
                new Handler(Looper.getMainLooper()).postDelayed(() -> { try { popup.stopLoading(); popup.destroy(); } catch(Exception ignored){} }, 200);
                return true;
            }
            @Override public void onCloseWindow(WebView window){ try { if(window != null) window.destroy(); } catch(Exception ignored) {} }
        });
        web.setDownloadListener((url, ua, cd, mime, len) -> { enqueueDirect(url, mime); });
        return web;
    }

    private void inject(WebView view){ try { view.evaluateJavascript(INJECT_JS, null); } catch (Exception ignored) {} }

    final class VaultBridge {
        @JavascriptInterface public void onUserPlay(final String src){
            final String u = src == null ? "" : src;
            runOnUiThread(() -> {
                if (isHttp(u) && !isBlockedAd(u)) {
                    playedUrl = u;
                    String t = typeOf(u); if (t == null) t = "mp4";
                    synchronized(media){ media.put(u, t); }
                    updateFab();
                }
            });
        }
    }

    private String typeOf(String url){
        if (url == null) return null;
        String low = url.toLowerCase(Locale.US);
        if (low.contains(".m3u8")) return "hls";
        if (low.contains(".mpd")) return null;
        if (low.matches(".*\\.mp4($|\\?.*)")) return "mp4";
        if (low.matches(".*\\.(mov|webm|mkv|m4v)($|\\?.*)")) return "mp4";
        return null;
    }

    private void inspect(String url) {
        if (url == null) return;
        if (isBlockedAd(url)) return;
        String type = typeOf(url);
        if (type == null) return;
        synchronized (media) { if (!media.containsKey(url)) { if (media.size() < 20) media.put(url, type); } }
        runOnUiThread(this::updateFab);
    }

    private boolean handlePopupUrl(WebView v, String u, boolean userGesture){
        if(u == null || u.trim().isEmpty()) return true;
        String low = u.toLowerCase(Locale.US);
        if(low.startsWith("about:blank") || low.startsWith("data:") || low.startsWith("blob:")) return true;
        if(!isHttp(u)){ toast("Redirection externe bloquée"); return true; }
        if(isBlockedAd(u)){ toast("Pub bloquée"); return true; }
        if(!userGesture){ toast("Popup bloqué"); return true; }
        newTab(u, true);
        return true;
    }

    private boolean guardUrl(WebView view, String url, boolean mainFrame, boolean userGesture){
        if(url==null) return true;
        String low=url.toLowerCase(Locale.US);
        if(low.startsWith("about:") || low.startsWith("data:") || low.startsWith("blob:")) return false;
        if(!isHttp(url)){ toast("Redirection externe bloquée"); return true; }
        if(mainFrame && isCleanDuckHome(url)){ loadCleanDuckHome(view); return true; }
        if(isBlockedAd(url)){ if(mainFrame) toast("Pub bloquée"); return true; } // bloque les redirections pub
        return false;
    }
    private boolean isHttp(String url){ if(url==null) return false; String l=url.toLowerCase(Locale.US); return l.startsWith("http://") || l.startsWith("https://"); }

    private void newTab(String url, boolean activate){
        WebView w = buildWebView(); tabs.add(w); tabTitles.add("Nouvel onglet");
        frame.addView(w, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        frame.bringChildToFront(fab); String startUrl=toUrl(url); if(isCleanDuckHome(startUrl)) loadCleanDuckHome(w); else w.loadUrl(startUrl);
        if(activate) switchTab(tabs.size()-1); else w.setVisibility(View.GONE);
    }
    private void switchTab(int idx){
        if(idx<0 || idx>=tabs.size()) return; activeTab=idx;
        for(int i=0;i<tabs.size();i++) tabs.get(i).setVisibility(i==idx?View.VISIBLE:View.GONE);
        frame.bringChildToFront(fab); WebView w=current(); if(w!=null) urlBar.setText(w.getUrl()==null?"":w.getUrl()); updateTabButton();
    }
    private void closeCurrentTab(){
        if(tabs.size()<=1){ go(DUCK_HOME); return; }
        WebView w=current(); int old=activeTab; tabs.remove(old); tabTitles.remove(old); frame.removeView(w); try{w.destroy();}catch(Exception ignored){}
        switchTab(Math.max(0, old-1));
    }
    private void updateTabButton(){ if(tabCount!=null) tabCount.setText(String.valueOf(tabs.size())); }

    // ===================== feuilles =====================
    private AlertDialog buildSheet(View content){
        AlertDialog dlg = new AlertDialog.Builder(this).setView(content).create();
        try {
            Window w = dlg.getWindow();
            if (w != null) { w.setBackgroundDrawable(new ColorDrawable(0x00000000)); WindowManager.LayoutParams lp = w.getAttributes(); lp.gravity = Gravity.BOTTOM; lp.width = ViewGroup.LayoutParams.MATCH_PARENT; w.setAttributes(lp); }
        } catch (Exception ignored) {}
        return dlg;
    }
    private LinearLayout sheetPanel(String title, String sub){
        LinearLayout box = new LinearLayout(this); box.setOrientation(LinearLayout.VERTICAL);
        box.setBackground(gd(cSurface(), 24)); box.setPadding(dp(18), dp(12), dp(18), dp(14));
        View handle = new View(this); handle.setBackground(gd(0x55FFFFFF, 3));
        LinearLayout.LayoutParams hlp = new LinearLayout.LayoutParams(dp(38), dp(4)); hlp.gravity = Gravity.CENTER_HORIZONTAL; hlp.bottomMargin = dp(12); handle.setLayoutParams(hlp); box.addView(handle);
        if (title != null) { TextView tt = new TextView(this); tt.setText(title); tt.setTextColor(cText()); tt.setTextSize(18.5f); tt.setPadding(0,0,0,dp(2)); box.addView(tt); }
        if (sub != null && !sub.isEmpty()) { TextView ss = new TextView(this); ss.setText(sub); ss.setTextColor(cMuted()); ss.setTextSize(13); ss.setPadding(0,0,0,dp(8)); box.addView(ss); }
        return box;
    }
    private ScrollView wrapScroll(View v) { ScrollView sv = new ScrollView(this); sv.addView(v); sv.setBackground(gd(cSurface(), 24)); return sv; }

    private void openMenu(){
        LinearLayout box = sheetPanel("Menu", null);
        final AlertDialog dlg = buildSheet(box);
        box.addView(menuRow("\u2795", "Nouvel onglet", v -> { dlg.dismiss(); newTab(DUCK_HOME, true); }));
        box.addView(menuRow("\u2630", "Historique", v -> { dlg.dismiss(); openHistoryDialog(); }));
        box.addView(menuRow("\u2913", "Téléchargements", v -> { dlg.dismiss(); openDownloads(); }));
        box.addView(menuRow(adblockOn ? "\u2714" : "\u2716", "Bloqueur de pub : " + (adblockOn ? "activé" : "désactivé"), v -> { adblockOn = !adblockOn; applyTheme(); dlg.dismiss(); WebView w=current(); if(w!=null) w.reload(); toast("Bloqueur " + (adblockOn?"activé":"désactivé")); }));
        box.addView(menuRow(allowCapture ? "\uD83D\uDCF7" : "\u26D4", "Captures d'écran/vidéo : " + (allowCapture ? "autorisées" : "bloquées"), v -> { allowCapture = !allowCapture; prefs.edit().putBoolean("allow_capture", allowCapture).apply(); applyCaptureFlag(); dlg.dismiss(); toast(allowCapture ? "Captures autorisées" : "Captures bloquées"); }));
        box.addView(menuRow("\u25D1", "Apparence", v -> { dlg.dismiss(); openAppearance(); }));
        box.addView(menuRow("\u29C9", "Copier le lien", v -> { dlg.dismiss(); copyLink(); }));
        box.addView(menuRow("\u2715", "Fermer le navigateur", v -> { dlg.dismiss(); finish(); }));
        dlg.show();
    }

    private void openAppearance(){
        LinearLayout box = sheetPanel("Apparence", "Thème et couleur d'accent");
        final AlertDialog dlg = buildSheet(box);
        TextView lt = new TextView(this); lt.setText("Thème"); lt.setTextColor(cMuted()); lt.setTextSize(12.5f); lt.setPadding(0, dp(4), 0, dp(8)); box.addView(lt);
        LinearLayout themeRow = new LinearLayout(this); themeRow.setOrientation(LinearLayout.HORIZONTAL);
        themeRow.addView(themeChip("Sombre", "dark", dlg)); themeRow.addView(themeChip("Noir AMOLED", "black", dlg));
        box.addView(themeRow);
        TextView la = new TextView(this); la.setText("Accent"); la.setTextColor(cMuted()); la.setTextSize(12.5f); la.setPadding(0, dp(16), 0, dp(8)); box.addView(la);
        LinearLayout accRow = new LinearLayout(this); accRow.setOrientation(LinearLayout.HORIZONTAL);
        accRow.addView(accentDot(0xFFFB542B, dlg)); accRow.addView(accentDot(0xFF3B7DED, dlg)); accRow.addView(accentDot(0xFF7C5CFF, dlg)); accRow.addView(accentDot(0xFF22C55E, dlg)); accRow.addView(accentDot(0xFFE0564B, dlg));
        box.addView(accRow);
        dlg.show();
    }
    private View themeChip(String label, final String value, final AlertDialog dlg){
        Button b = new Button(this); b.setAllCaps(false); b.setText(label); b.setTextSize(14);
        boolean sel = theme.equals(value);
        b.setTextColor(sel ? 0xFF1A1407 : cText());
        b.setBackground(sel ? gd(accent, 14) : gdStroke(Color.TRANSPARENT, 14, 0x33FFFFFF, 1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f); lp.setMargins(0,0,dp(8),0); b.setLayoutParams(lp);
        b.setOnClickListener(v -> { theme = value; applyTheme(); dlg.dismiss(); openAppearance(); });
        return b;
    }
    private View accentDot(final int color, final AlertDialog dlg){
        FrameLayout wrap = new FrameLayout(this);
        LinearLayout.LayoutParams wlp = new LinearLayout.LayoutParams(dp(46), dp(46)); wlp.setMargins(0,0,dp(10),0); wrap.setLayoutParams(wlp);
        View dot = new View(this);
        GradientDrawable g = new GradientDrawable(); g.setShape(GradientDrawable.OVAL); g.setColor(color);
        if (accent == color) g.setStroke(dp(3), cText());
        dot.setBackground(g);
        wrap.addView(dot, new FrameLayout.LayoutParams(dp(40), dp(40), Gravity.CENTER));
        wrap.setOnClickListener(v -> { accent = color; applyTheme(); dlg.dismiss(); openAppearance(); });
        return wrap;
    }
    private Button menuRow(String glyph, String label, View.OnClickListener cl){
        Button b = new Button(this); b.setAllCaps(false); b.setText("   " + glyph + "    " + label);
        b.setTextColor(cText()); b.setTextSize(15.5f); b.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        b.setBackground(gd(Color.TRANSPARENT, 12)); b.setPadding(dp(8), dp(14), dp(8), dp(14));
        b.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        b.setOnClickListener(cl); return b;
    }
    private void copyLink(){
        WebView w = current(); String u = w == null ? null : w.getUrl();
        if (u == null || u.isEmpty()) { toast("Aucun lien"); return; }
        try { ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE); cm.setPrimaryClip(ClipData.newPlainText("url", u)); toast("Lien copié"); } catch (Exception e) { toast("Impossible de copier"); }
    }
    private void openDownloads(){ android.content.Intent di = new android.content.Intent(this, DownloadsActivity.class); di.putExtra("vault", activeVault); startActivity(di); }

    private void openTabsDialog(){
        final LinearLayout box = sheetPanel("Onglets", tabs.size() + (tabs.size() > 1 ? " onglets ouverts" : " onglet ouvert"));
        final AlertDialog dlg = buildSheet(wrapScroll(box));

        final LinearLayout grid = new LinearLayout(this); grid.setOrientation(LinearLayout.VERTICAL);
        box.addView(grid);
        rebuildTabGrid(grid, dlg);

        Button n = choice("\u2795  Nouvel onglet", "DuckDuckGo");
        n.setOnClickListener(v -> { dlg.dismiss(); newTab(DUCK_HOME, true); });
        box.addView(n);
        dlg.show();
    }

    private void rebuildTabGrid(final LinearLayout grid, final AlertDialog dlg){
        grid.removeAllViews();
        LinearLayout rowRef = null;
        for (int i = 0; i < tabs.size(); i++) {
            if (i % 2 == 0) {
                rowRef = new LinearLayout(this); rowRef.setOrientation(LinearLayout.HORIZONTAL);
                LinearLayout.LayoutParams rlp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
                rlp.topMargin = dp(8); rowRef.setLayoutParams(rlp);
                grid.addView(rowRef);
            }
            rowRef.addView(tabCard(i, grid, dlg));
        }
        // Si nombre impair, remplir l'espace vide à droite pour garder l'alignement.
        if (tabs.size() % 2 == 1 && rowRef != null) {
            View spacer = new View(this);
            spacer.setLayoutParams(new LinearLayout.LayoutParams(0, 1, 1f));
            rowRef.addView(spacer);
        }
    }

    private View tabCard(final int idx, final LinearLayout grid, final AlertDialog dlg){
        final boolean active = (idx == activeTab);
        final LinearLayout card = new LinearLayout(this); card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(active ? gdStroke(cBg(), 16, accent, 2) : gd(cBg(), 16));
        card.setPadding(dp(12), dp(10), dp(12), dp(12));
        LinearLayout.LayoutParams clp = new LinearLayout.LayoutParams(0, dp(132), 1f);
        clp.setMargins(0, 0, (idx % 2 == 0) ? dp(8) : 0, 0); card.setLayoutParams(clp);

        // En-tête : pastille + titre + X
        LinearLayout head = new LinearLayout(this); head.setOrientation(LinearLayout.HORIZONTAL); head.setGravity(Gravity.CENTER_VERTICAL);
        View dot = new View(this);
        GradientDrawable og = new GradientDrawable(); og.setShape(GradientDrawable.OVAL); og.setColor(active ? accent : 0xFF555B68);
        dot.setBackground(og);
        LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(dp(10), dp(10)); dlp.rightMargin = dp(8); dot.setLayoutParams(dlp);
        TextView title = new TextView(this); title.setText(tabTitles.get(idx)); title.setTextColor(cText()); title.setTextSize(13.5f);
        title.setSingleLine(true); title.setEllipsize(TextUtils.TruncateAt.END);
        title.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView x = new TextView(this); x.setText("\u2715"); x.setTextColor(cMuted()); x.setTextSize(16); x.setGravity(Gravity.CENTER);
        x.setPadding(dp(8), dp(2), dp(2), dp(2));
        x.setOnClickListener(v -> closeTabAt(idx, grid, dlg));
        head.addView(dot); head.addView(title); head.addView(x);
        card.addView(head);

        // Corps : aperçu (domaine)
        TextView body = new TextView(this); body.setText(shortUrl(safeUrl(tabs.get(idx).getUrl())));
        body.setTextColor(cMuted()); body.setTextSize(12); body.setSingleLine(true); body.setEllipsize(TextUtils.TruncateAt.END);
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        blp.topMargin = dp(10); body.setLayoutParams(blp);
        body.setBackground(gd(cSurface(), 12)); body.setPadding(dp(10), dp(10), dp(10), dp(10));
        card.addView(body);

        // Tap = ouvrir l'onglet ; balayer horizontalement = fermer.
        card.setOnClickListener(v -> { dlg.dismiss(); switchTab(idx); });
        attachSwipeToClose(card, () -> closeTabAt(idx, grid, dlg));
        return card;
    }

    // Fermer un onglet depuis la grille puis reconstruire (sans fermer la feuille).
    private void closeTabAt(int idx, final LinearLayout grid, final AlertDialog dlg){
        if (idx < 0 || idx >= tabs.size()) return;
        if (tabs.size() <= 1) {
            // Dernier onglet : on le recharge sur la page d'accueil au lieu de tout fermer.
            go(DUCK_HOME); dlg.dismiss(); return;
        }
        WebView w = tabs.get(idx); tabs.remove(idx); tabTitles.remove(idx);
        frame.removeView(w); try { w.destroy(); } catch (Exception ignored) {}
        if (activeTab >= tabs.size()) activeTab = tabs.size() - 1;
        else if (idx <= activeTab && activeTab > 0) activeTab--;
        switchTab(activeTab);
        rebuildTabGrid(grid, dlg);
    }

    // Balayage horizontal pour fermer une carte (comme un onglet qu'on jette).
    private void attachSwipeToClose(final View card, final Runnable onClose){
        card.setOnTouchListener(new View.OnTouchListener(){
            float startX = 0, startY = 0; boolean swiping = false;
            @Override public boolean onTouch(View v, android.view.MotionEvent ev){
                switch (ev.getAction()) {
                    case android.view.MotionEvent.ACTION_DOWN:
                        startX = ev.getRawX(); startY = ev.getRawY(); swiping = false; return false;
                    case android.view.MotionEvent.ACTION_MOVE: {
                        float dx = ev.getRawX() - startX, dy = ev.getRawY() - startY;
                        if (Math.abs(dx) > dp(14) && Math.abs(dx) > Math.abs(dy) * 1.5f) { swiping = true; v.setTranslationX(dx); v.setAlpha(Math.max(0.2f, 1f - Math.abs(dx) / (v.getWidth() + 1f))); return true; }
                        return false;
                    }
                    case android.view.MotionEvent.ACTION_UP:
                    case android.view.MotionEvent.ACTION_CANCEL: {
                        float dx = ev.getRawX() - startX;
                        if (swiping && Math.abs(dx) > dp(90)) { onClose.run(); return true; }
                        if (swiping) { v.animate().translationX(0).alpha(1f).setDuration(150).start(); return true; }
                        return false;
                    }
                }
                return false;
            }
        });
    }

    private void openHistoryDialog(){
        final LinearLayout box = sheetPanel("Historique", "Les 100 dernières pages de ce coffre");
        final AlertDialog dlg = buildSheet(wrapScroll(box));
        final EditText search = new EditText(this);
        search.setHint("Filtrer l'historique"); search.setSingleLine(true);
        search.setTextColor(cText()); search.setHintTextColor(cMuted());
        search.setBackground(gd(cBg(), 14)); search.setPadding(dp(14), dp(10), dp(14), dp(10)); search.setTextSize(14);
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); slp.bottomMargin = dp(8); search.setLayoutParams(slp);
        box.addView(search);
        final LinearLayout listHolder = new LinearLayout(this); listHolder.setOrientation(LinearLayout.VERTICAL); box.addView(listHolder);
        final Runnable[] r = new Runnable[1];
        r[0] = () -> {
            listHolder.removeAllViews();
            String q = search.getText().toString().trim().toLowerCase(Locale.US);
            JSONArray arr = history(); int shown = 0;
            for (int i=0;i<arr.length();i++){
                try{ JSONObject o=arr.getJSONObject(i); final String u=o.optString("url"); String t=o.optString("title","Page");
                    if (!q.isEmpty() && !(t.toLowerCase(Locale.US).contains(q) || u.toLowerCase(Locale.US).contains(q))) continue;
                    listHolder.addView(historyRow(t, u, dlg)); shown++; }catch(Exception ignored){}
            }
            if (shown == 0) { TextView none=new TextView(this); none.setText("Aucun historique."); none.setTextColor(cMuted()); none.setPadding(0,dp(12),0,dp(12)); listHolder.addView(none); }
        };
        r[0].run();
        search.addTextChangedListener(new android.text.TextWatcher(){ public void beforeTextChanged(CharSequence s,int a,int b,int c){} public void onTextChanged(CharSequence s,int a,int b,int c){ r[0].run(); } public void afterTextChanged(android.text.Editable s){} });
        Button clear=choice("\uD83D\uDDD1  Vider l'historique", ""); clear.setOnClickListener(v->{prefs.edit().remove("history").apply(); dlg.dismiss(); toast("Historique vidé");}); box.addView(clear);
        dlg.show();
    }
    private View historyRow(final String title, final String url, final AlertDialog dlg){
        LinearLayout row = new LinearLayout(this); row.setOrientation(LinearLayout.HORIZONTAL); row.setGravity(Gravity.CENTER_VERTICAL);
        row.setBackground(gd(cBg(), 14)); row.setPadding(dp(10), dp(10), dp(10), dp(10));
        LinearLayout.LayoutParams rlp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); rlp.topMargin = dp(8); row.setLayoutParams(rlp);
        TextView av = new TextView(this);
        String letter = (title != null && !title.trim().isEmpty()) ? title.trim().substring(0,1).toUpperCase(Locale.US) : "\u2022";
        av.setText(letter); av.setTextColor(0xFF1A1407); av.setGravity(Gravity.CENTER); av.setTextSize(15);
        GradientDrawable og = new GradientDrawable(); og.setShape(GradientDrawable.OVAL); og.setColor(accent); av.setBackground(og);
        LinearLayout.LayoutParams alp = new LinearLayout.LayoutParams(dp(34), dp(34)); alp.rightMargin = dp(12); av.setLayoutParams(alp); row.addView(av);
        LinearLayout col = new LinearLayout(this); col.setOrientation(LinearLayout.VERTICAL);
        col.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView tt = new TextView(this); tt.setText(title); tt.setTextColor(cText()); tt.setTextSize(14.5f); tt.setSingleLine(true); tt.setEllipsize(TextUtils.TruncateAt.END);
        TextView su = new TextView(this); su.setText(shortUrl(url)); su.setTextColor(cMuted()); su.setTextSize(12.5f); su.setSingleLine(true); su.setEllipsize(TextUtils.TruncateAt.END);
        col.addView(tt); col.addView(su); row.addView(col);
        row.setOnClickListener(v -> { dlg.dismiss(); go(url); });
        return row;
    }

    private JSONArray history(){ try{return new JSONArray(prefs.getString("history","[]"));}catch(Exception e){return new JSONArray();} }
    private void saveHistory(String title, String url){
        if(!isHttp(url)) return;
        try{
            JSONArray old=history(), arr=new JSONArray(); JSONObject first=new JSONObject(); first.put("title", title); first.put("url", url); first.put("time", System.currentTimeMillis()); arr.put(first);
            for(int i=0;i<old.length() && arr.length()<100;i++){ JSONObject o=old.getJSONObject(i); if(!url.equals(o.optString("url"))) arr.put(o); }
            prefs.edit().putString("history", arr.toString()).apply();
        }catch(Exception ignored){}
    }

    private void updateFab() { int n; synchronized (media) { n = media.size(); } if (n > 0) { fab.setText("\u2913  Télécharger" + (n>1 ? " ("+n+")" : "")); fab.setVisibility(View.VISIBLE); } else fab.setVisibility(View.GONE); }
    private void go(String input) { WebView w=current(); if(w==null)return; String url=toUrl(input); urlBar.setText(url); hideKb(); if(isCleanDuckHome(url)) loadCleanDuckHome(w); else w.loadUrl(url); }
    private void hideKb(){ try{ InputMethodManager im=(InputMethodManager)getSystemService(INPUT_METHOD_SERVICE); if(im!=null) im.hideSoftInputFromWindow(urlBar.getWindowToken(),0);}catch(Exception ignored){} }
    private String toUrl(String input) { if(input==null)input=""; input=input.trim(); if(input.isEmpty()) return DUCK_HOME; if(input.matches("^[a-zA-Z][a-zA-Z0-9+.-]*://.*")) return input; boolean looksUrl=input.contains(".")&&!input.contains(" "); if(looksUrl)return "https://"+input; try{return "https://duckduckgo.com/?q="+java.net.URLEncoder.encode(input,"UTF-8");}catch(Exception e){return DUCK_HOME;} }
    private String cookieFor(String url) { try { return CookieManager.getInstance().getCookie(url); } catch (Exception e) { return null; } }
    private String ua() { try { WebView w=current(); return w==null?null:w.getSettings().getUserAgentString(); } catch (Exception e) { return null; } }
    private String referer() { try { WebView w=current(); return w==null?null:w.getUrl(); } catch (Exception e) { return null; } }

    private void enqueueDirect(String url, String mime) { String name=guessName(url,false); Downloads.get().enqueue(getApplicationContext(), url, name, (mime != null ? mime : "video/mp4"), false, referer(), ua(), cookieFor(url), activeVault); toast("Téléchargement ajouté"); openDownloads(); }

    private void openSheet() {
        final List<String> urls = new ArrayList<>(); final List<String> types = new ArrayList<>();
        // La video lancee par l'utilisateur passe en premier.
        synchronized (media) {
            if (playedUrl != null && media.containsKey(playedUrl)) { urls.add(playedUrl); types.add(media.get(playedUrl)); }
            for (Map.Entry<String, String> e : media.entrySet()) { if (playedUrl != null && playedUrl.equals(e.getKey())) continue; urls.add(e.getKey()); types.add(e.getValue()); }
        }
        if (urls.isEmpty()) { toast("Lance la vidéo (touche Play) puis reviens télécharger."); return; }
        final LinearLayout box = sheetPanel("Télécharger dans la galerie", "Choisis la vidéo / la qualité");
        final AlertDialog dlg = buildSheet(wrapScroll(box));
        for (int i = 0; i < urls.size(); i++) {
            final String u = urls.get(i); final String type = types.get(i);
            final boolean isPlayed = (playedUrl != null && playedUrl.equals(u));
            final String prefix = isPlayed ? "\u25B6 Vidéo en lecture — " : "";
            if ("hls".equals(type)) {
                final Button bload = choice(prefix + "Flux HLS — analyser les qualités", shortUrl(u));
                bload.setOnClickListener(v -> { bload.setText("Analyse en cours…"); new Thread(() -> { final List<Hls.Variant> vs = analyzeHls(u); runOnUiThread(() -> { box.removeView(bload); if (vs == null || vs.isEmpty()) { Button bb = choice("Télécharger (HLS)", shortUrl(u)); bb.setOnClickListener(x -> { dlg.dismiss(); enqueueHls(u, u); }); box.addView(bb); } else { for (final Hls.Variant vv : vs) { String label = (vv.height > 0) ? (vv.height + "p") : (vv.resolution.isEmpty() ? "Qualité" : vv.resolution); String slabel = (vv.bandwidth > 0) ? ((vv.bandwidth / 1000) + " kbps") : "HLS"; Button bb = choice(label, slabel); bb.setOnClickListener(x -> { dlg.dismiss(); enqueueHls(vv.url, u); }); box.addView(bb); } } }); }).start(); });
                box.addView(bload);
            } else { final Button bb = choice(prefix + "Vidéo MP4", shortUrl(u)); bb.setOnClickListener(v -> { dlg.dismiss(); enqueueDirectFromSheet(u); }); box.addView(bb); }
        }
        Button cancel = choice("Fermer", ""); cancel.setOnClickListener(v -> dlg.dismiss()); box.addView(cancel); dlg.show();
    }
    private List<Hls.Variant> analyzeHls(String url) { try { Downloads.Task probe = new Downloads.Task(); probe.referer = referer(); probe.ua = ua(); probe.cookie = cookieFor(url); String txt = Downloads.get().probeText(url, probe); if (Hls.isMaster(txt)) { List<Hls.Variant> vs = Hls.parseMaster(txt, url); Collections.sort(vs, (a, b) -> Long.compare(b.bandwidth, a.bandwidth)); return vs; } } catch (Exception ignored) {} return null; }
    private void enqueueHls(String variantUrl, String origin) { String name=guessName(origin,true); Downloads.get().enqueue(getApplicationContext(), variantUrl, name, "video/mp2t", true, referer(), ua(), cookieFor(variantUrl), activeVault); toast("Téléchargement ajouté"); openDownloads(); }
    private void enqueueDirectFromSheet(String u) { String name=guessName(u,false); Downloads.get().enqueue(getApplicationContext(), u, name, "video/mp4", false, referer(), ua(), cookieFor(u), activeVault); toast("Téléchargement ajouté"); openDownloads(); }
    private String guessName(String url, boolean hls) { String base = (pageTitle != null && !pageTitle.trim().isEmpty()) ? pageTitle : "video"; base = base.replaceAll("[\\\\/:*?\"<>|]", "_").trim(); if (base.length() > 60) base = base.substring(0, 60); String ext = hls ? "ts" : "mp4"; try { String path = new java.net.URL(url).getPath(); String fn = path.substring(path.lastIndexOf('/') + 1); if (fn.contains(".")) { String e = fn.substring(fn.lastIndexOf('.') + 1).toLowerCase(Locale.US); if (e.matches("mp4|mov|mkv|webm|m4v|ts")) ext = e; } } catch (Exception ignored) {} return base + "." + ext; }
    private String shortUrl(String u) { try { return new java.net.URL(u).getHost(); } catch (Exception e) { return (u != null && u.length() > 40) ? u.substring(0, 40) + "…" : (u==null?"":u); } }
    private String safeUrl(String u){ return u==null?"":u; }
    private String cleanTitle(String t, String u){ if(t==null||t.trim().isEmpty()) return shortUrl(u==null?"":u); t=t.trim(); return t.length()>70?t.substring(0,70):t; }

    private Button choice(String title, String sub) {
        Button b = new Button(this); b.setAllCaps(false);
        b.setText((sub == null || sub.isEmpty()) ? title : (title + "\n" + sub));
        b.setTextColor(cText()); b.setBackground(gd(cBg(), 14)); b.setTextSize(14.5f);
        b.setGravity(Gravity.CENTER_VERTICAL | Gravity.START); b.setPadding(dp(14), dp(12), dp(14), dp(12));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT); lp.setMargins(0, dp(8), 0, 0); b.setLayoutParams(lp); return b;
    }
    private Button roundIcon(String t) { Button b = new Button(this); b.setText(t); b.setAllCaps(false); b.setTextColor(cText()); b.setBackground(gd(Color.TRANSPARENT, 18)); b.setTextSize(16); b.setMinWidth(dp(34)); b.setMinHeight(dp(34)); b.setPadding(dp(6), dp(4), dp(6), dp(4)); return b; }
    private Button navIcon(String t) { Button b = new Button(this); b.setText(t); b.setAllCaps(false); b.setTextColor(cText()); b.setBackground(gd(Color.TRANSPARENT, 16)); b.setTextSize(22); b.setPadding(dp(6), dp(6), dp(6), dp(6)); b.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)); return b; }
    private void toast(String t) { Toast.makeText(this, t, Toast.LENGTH_SHORT).show(); }
    private int dp(int v) { return (int) (v * getResources().getDisplayMetrics().density); }

    @Override protected void onResume(){ super.onResume(); browserAlive = true; LockControlPlugin.suspended = true; if(prefs != null) prefs.edit().putBoolean("browser_open", true).apply(); }
    @Override protected void onPause(){ if(prefs != null) prefs.edit().putString("resume_url", safeUrl(current()==null?null:current().getUrl())).putBoolean("browser_open", true).apply(); super.onPause(); }
    @Override public void onUserLeaveHint(){
        // Accueil / Récents : on revient à la calculatrice.
        LockControlPlugin.suspended = false;
        LockControlPlugin.lockOnResume = true;
        super.onUserLeaveHint();
        finish();
    }
    @Override public void onBackPressed() { WebView w=current(); if (w != null && w.canGoBack()) w.goBack(); else super.onBackPressed(); }
    @Override protected void onDestroy() { browserAlive = false; for(WebView w:tabs){ try{w.destroy();}catch(Exception ignored){} } super.onDestroy(); }
}
EOFJAVA


# ===== VaultSecurity : biométrie + FLAG_SECURE =====
cat > "$PKG_DIR/VaultSecurityPlugin.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.view.WindowManager;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.core.content.ContextCompat;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.util.concurrent.Executor;

@CapacitorPlugin(name = "VaultSecurity")
public class VaultSecurityPlugin extends Plugin {
    @PluginMethod
    public void setFlagSecure(PluginCall call) {
        boolean enabled = call.getBoolean("enabled", false);
        Activity a = getActivity();
        new Handler(Looper.getMainLooper()).post(() -> {
            if (enabled) a.getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
            else a.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
            call.resolve();
        });
    }

    @PluginMethod
    public void authenticate(PluginCall call) {
        Activity a = getActivity();
        Executor ex = ContextCompat.getMainExecutor(a);
        int can = BiometricManager.from(a).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.DEVICE_CREDENTIAL);
        if (can != BiometricManager.BIOMETRIC_SUCCESS) { call.resolve(); return; }
        String reason = call.getString("reason", "Déverrouiller le coffre");
        BiometricPrompt prompt = new BiometricPrompt((androidx.fragment.app.FragmentActivity)a, ex, new BiometricPrompt.AuthenticationCallback() {
            @Override public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) { call.resolve(); }
            @Override public void onAuthenticationError(int errorCode, CharSequence errString) { call.reject(String.valueOf(errString)); }
            @Override public void onAuthenticationFailed() { }
        });
        BiometricPrompt.PromptInfo info = new BiometricPrompt.PromptInfo.Builder()
            .setTitle("Authentification")
            .setSubtitle(reason)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG | BiometricManager.Authenticators.DEVICE_CREDENTIAL)
            .build();
        new Handler(Looper.getMainLooper()).post(() -> prompt.authenticate(info));
    }
}
EOFJAVA

# ===== SecurityPlugin : échecs maître chiffrés + wipe complet + root/tamper =====
cat > "$PKG_DIR/SecurityPlugin.java" <<'EOFJAVA'
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
EOFJAVA

# ===== CameraRecorder : enregistrement caméra natif avec Foreground Service visible =====
cat > "$PKG_DIR/CameraRecorderPlugin.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.Manifest;
import android.content.Intent;
import com.getcapacitor.JSObject;
import com.getcapacitor.PermissionState;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.annotation.PermissionCallback;

@CapacitorPlugin(
    name = "CameraRecorder",
    permissions = {
        @Permission(strings = { Manifest.permission.CAMERA }, alias = "camera"),
        @Permission(strings = { Manifest.permission.RECORD_AUDIO }, alias = "audio")
    }
)
public class CameraRecorderPlugin extends Plugin {
    @PluginMethod
    public void isRecording(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("recording", CameraRecordingService.isRecording());
        ret.put("mode", CameraRecordingService.currentMode());
        call.resolve(ret);
    }

    @PluginMethod
    public void start(PluginCall call) {
        // Empêche l'auto-verrouillage pendant les fenêtres d'autorisation Android.
        LockControlPlugin.suspendForPermissions();
        if (getPermissionState("camera") != PermissionState.GRANTED) {
            requestPermissionForAlias("camera", call, "cameraPermsCallback");
            return;
        }
        if (getPermissionState("audio") != PermissionState.GRANTED) {
            requestPermissionForAlias("audio", call, "audioPermsCallback");
            return;
        }
        startNow(call);
    }

    @PermissionCallback private void cameraPermsCallback(PluginCall call) { if (getPermissionState("camera") == PermissionState.GRANTED) start(call); else { call.reject("Permission caméra refusée"); } }
    @PermissionCallback private void audioPermsCallback(PluginCall call) { if (getPermissionState("audio") == PermissionState.GRANTED) start(call); else { call.reject("Permission micro refusée"); } }

    private void startNow(PluginCall call) {
        try {
            String mode = call.getString("mode", "back"); // back, front, dual
            boolean audio = call.getBoolean("audio", true);
            Intent i = new Intent(getContext(), CameraRecordingService.class);
            i.setAction(CameraRecordingService.ACTION_START);
            i.putExtra("mode", mode);
            i.putExtra("audio", audio);
            i.putExtra("vault", VaultStore.cleanVault(call.getString("vault", "main")));
            getContext().startService(i);
            JSObject ret = new JSObject(); ret.put("recording", true); ret.put("mode", mode); call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }

    @PluginMethod
    public void stop(PluginCall call) {
        try {
            Intent i = new Intent(getContext(), CameraRecordingService.class);
            i.setAction(CameraRecordingService.ACTION_STOP);
            getContext().startService(i);
            JSObject ret = new JSObject(); ret.put("recording", false); call.resolve(ret);
        } catch (Exception e) { call.reject(e.getMessage(), e); }
    }
}
EOFJAVA

cat > "$PKG_DIR/CameraRecordingService.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.media.MediaMetadataRetriever;
import android.media.MediaRecorder;
import android.media.MediaScannerConnection;
import android.os.Environment;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.util.Size;
import android.view.Surface;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public class CameraRecordingService extends Service {
    public static final String ACTION_START = "com.capmaster2023.admincalculator.camera.START";
    public static final String ACTION_STOP = "com.capmaster2023.admincalculator.camera.STOP";
    private static final String CHANNEL_ID = "camera_recording_channel";
    private static final int NOTIF_ID = 7402;
    private static volatile boolean recording = false;
    private static volatile String modeNow = "back";

    private HandlerThread thread;
    private Handler handler;
    private CameraDevice camera;
    private CameraCaptureSession session;
    private MediaRecorder recorder;
    private File outputFile;
    private long startedAt = 0L;
    private boolean audioEnabled = true;
    private String activeVault = "main";
    private DualUnit backUnit;
    private DualUnit frontUnit;

    private static class DualUnit {
        CameraDevice camera;
        CameraCaptureSession session;
        MediaRecorder recorder;
        File file;
        boolean front;
        boolean audio;
        boolean started;
    }

    public static boolean isRecording() { return recording; }
    public static String currentMode() { return modeNow; }
    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent == null ? "" : intent.getAction();
        if (ACTION_STOP.equals(action)) {
            stopRecording(); stopSelf(); return START_NOT_STICKY;
        }
        if (ACTION_START.equals(action) && !recording) {
            modeNow = intent.getStringExtra("mode"); if (modeNow == null) modeNow = "back";
            audioEnabled = intent.getBooleanExtra("audio", true);
            activeVault = VaultStore.cleanVault(intent.getStringExtra("vault"));
            if ("dual".equals(modeNow)) startDualRecording(); else startRecording(modeNow);
        }
        return START_STICKY;
    }

    @SuppressLint("MissingPermission")
    private void startRecording(String wantedMode) {
        try {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) { stopSelf(); return; }
            if (audioEnabled && ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) audioEnabled = false;
            thread = new HandlerThread("CameraRecordingThread"); thread.start(); handler = new Handler(thread.getLooper());
            CameraManager manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            String cameraId = chooseCamera(manager, "front".equals(wantedMode));
            Size size = chooseSize(manager, cameraId);
            prepareRecorder(size);
            manager.openCamera(cameraId, new CameraDevice.StateCallback() {
                @Override public void onOpened(@NonNull CameraDevice cam) { camera = cam; createSession(); }
                @Override public void onDisconnected(@NonNull CameraDevice cam) { stopRecording(); }
                @Override public void onError(@NonNull CameraDevice cam, int error) { stopRecording(); }
            }, handler);
        } catch (Exception e) { stopRecording(); stopSelf(); }
    }

    @SuppressLint("MissingPermission")
    private void startDualRecording() {
        try {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) { stopSelf(); return; }
            if (audioEnabled && ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) audioEnabled = false;
            thread = new HandlerThread("DualCameraRecordingThread"); thread.start(); handler = new Handler(thread.getLooper());
            CameraManager manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            String backId = chooseCamera(manager, false);
            String frontId = chooseCamera(manager, true);
            if (backId.equals(frontId)) throw new Exception("Aucune caméra frontale/arrière distincte trouvée");
            backUnit = prepareDualUnit(manager, backId, false, audioEnabled);
            frontUnit = prepareDualUnit(manager, frontId, true, false);
            openDualCamera(manager, backId, backUnit);
            openDualCamera(manager, frontId, frontUnit);
            recording = true;
        } catch (Exception e) {
            stopRecording(); stopSelf();
        }
    }

    private DualUnit prepareDualUnit(CameraManager manager, String cameraId, boolean front, boolean audio) throws Exception {
        DualUnit u = new DualUnit(); u.front = front; u.audio = audio;
        Size size = chooseSize(manager, cameraId);
        String suffix = front ? "_front.mp4" : "_back.mp4";
        u.file = new File(VaultStore.dir(this, activeVault), "duo_" + System.currentTimeMillis() + suffix);
        u.recorder = makeRecorder(u.file, size, front, audio);
        return u;
    }

    @SuppressLint("MissingPermission")
    private void openDualCamera(CameraManager manager, String id, final DualUnit u) throws Exception {
        manager.openCamera(id, new CameraDevice.StateCallback() {
            @Override public void onOpened(@NonNull CameraDevice cam) { u.camera = cam; createDualSession(u); }
            @Override public void onDisconnected(@NonNull CameraDevice cam) { stopRecording(); }
            @Override public void onError(@NonNull CameraDevice cam, int error) { stopRecording(); }
        }, handler);
    }

    private void createDualSession(final DualUnit u) {
        try {
            final Surface surface = u.recorder.getSurface();
            u.camera.createCaptureSession(Arrays.asList(surface), new CameraCaptureSession.StateCallback() {
                @Override public void onConfigured(@NonNull CameraCaptureSession s) {
                    try {
                        u.session = s;
                        CaptureRequest.Builder b = u.camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
                        b.addTarget(surface);
                        s.setRepeatingRequest(b.build(), null, handler);
                        u.recorder.start(); u.started = true;
                    } catch (Exception e) { stopRecording(); }
                }
                @Override public void onConfigureFailed(@NonNull CameraCaptureSession s) { stopRecording(); }
            }, handler);
        } catch (Exception e) { stopRecording(); }
    }

    private String chooseCamera(CameraManager manager, boolean front) throws CameraAccessException {
        int target = front ? CameraCharacteristics.LENS_FACING_FRONT : CameraCharacteristics.LENS_FACING_BACK;
        for (String id : manager.getCameraIdList()) {
            Integer facing = manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
            if (facing != null && facing == target) return id;
        }
        return manager.getCameraIdList()[0];
    }

    private Size chooseSize(CameraManager manager, String cameraId) throws CameraAccessException {
        android.hardware.camera2.params.StreamConfigurationMap map = manager.getCameraCharacteristics(cameraId).get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        if (map != null) {
            Size[] sizes = map.getOutputSizes(MediaRecorder.class);
            if (sizes != null && sizes.length > 0) {
                for (Size s : sizes) if (s.getWidth() == 1280 && s.getHeight() == 720) return s;
                for (Size s : sizes) if (s.getWidth() <= 1920 && s.getHeight() <= 1080) return s;
                return sizes[0];
            }
        }
        return new Size(1280, 720);
    }

    private MediaRecorder makeRecorder(File file, Size size, boolean front, boolean audio) throws Exception {
        MediaRecorder r = new MediaRecorder();
        if (audio) r.setAudioSource(MediaRecorder.AudioSource.MIC);
        r.setVideoSource(MediaRecorder.VideoSource.SURFACE);
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        r.setOutputFile(file.getAbsolutePath());
        r.setVideoEncodingBitRate(4_000_000);
        r.setVideoFrameRate(30);
        r.setVideoSize(size.getWidth(), size.getHeight());
        r.setVideoEncoder(MediaRecorder.VideoEncoder.H264);
        if (audio) {
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            r.setAudioEncodingBitRate(128000);
            r.setAudioSamplingRate(44100);
        }
        r.setOrientationHint(front ? 270 : 90);
        r.prepare(); return r;
    }

    private void prepareRecorder(Size size) throws Exception {
        String id = "camera_" + System.currentTimeMillis();
        outputFile = new File(VaultStore.dir(this, activeVault), id + ".mp4");
        recorder = makeRecorder(outputFile, size, "front".equals(modeNow), audioEnabled);
        startedAt = System.currentTimeMillis();
    }

    private void createSession() {
        try {
            Surface surface = recorder.getSurface();
            camera.createCaptureSession(Arrays.asList(surface), new CameraCaptureSession.StateCallback() {
                @Override public void onConfigured(@NonNull CameraCaptureSession s) {
                    try {
                        session = s;
                        CaptureRequest.Builder b = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
                        b.addTarget(surface);
                        s.setRepeatingRequest(b.build(), null, handler);
                        recorder.start(); recording = true;
                    } catch (Exception e) { stopRecording(); }
                }
                @Override public void onConfigureFailed(@NonNull CameraCaptureSession s) { stopRecording(); }
            }, handler);
        } catch (Exception e) { stopRecording(); }
    }

    private void stopRecording() {
        boolean was = recording; recording = false;
        if ("dual".equals(modeNow)) { stopDual(was); return; }
        try { if (session != null) session.close(); } catch (Exception ignored) {}
        try { if (recorder != null) { recorder.stop(); recorder.reset(); recorder.release(); } } catch (Exception ignored) {}
        try { if (camera != null) camera.close(); } catch (Exception ignored) {}
        try { if (thread != null) thread.quitSafely(); } catch (Exception ignored) {}
        if (was && outputFile != null && outputFile.exists() && outputFile.length() > 0) addToVault(outputFile);
        session = null; recorder = null; camera = null; thread = null; handler = null;
    }

    private void stopDual(boolean was) {
        try { stopUnit(backUnit); } catch (Exception ignored) {}
        try { stopUnit(frontUnit); } catch (Exception ignored) {}
        try { if (thread != null) thread.quitSafely(); } catch (Exception ignored) {}
        if (was && backUnit != null && frontUnit != null && backUnit.file != null && frontUnit.file != null) {
            File out = new File(recordingsDir(), "duo_combined_" + System.currentTimeMillis() + ".mp4");
            if (mergeDuo(backUnit.file, frontUnit.file, out)) addToVault(out);
            else { addToVault(backUnit.file); addToVault(frontUnit.file); }
        }
        backUnit = null; frontUnit = null; thread = null; handler = null;
    }

    private void stopUnit(DualUnit u) {
        if (u == null) return;
        try { if (u.session != null) u.session.close(); } catch (Exception ignored) {}
        try { if (u.recorder != null) { if (u.started) u.recorder.stop(); u.recorder.reset(); u.recorder.release(); } } catch (Exception ignored) {}
        try { if (u.camera != null) u.camera.close(); } catch (Exception ignored) {}
    }

    private boolean mergeDuo(File back, File front, File out) {
        // FFmpeg Kit is no longer used because the old dependency is unavailable on Maven.
        // If dual-camera recording is used, the app safely keeps the two videos separately.
        return false;
    }

    private File recordingsDir() {
        File dir = getExternalFilesDir(Environment.DIRECTORY_MOVIES);
        if (dir == null) dir = new File(getFilesDir(), "camera_recordings");
        if (!dir.exists()) dir.mkdirs();
        return dir;
    }

    private void addToVault(File f) {
        try {
            MediaScannerConnection.scanFile(this, new String[]{f.getAbsolutePath()}, new String[]{"video/mp4"}, null);
        } catch (Exception ignored) {}
        try {
            String id = f.getName().replace(".mp4", "");
            File thumb = makeThumb(f, id);
            JSONObject e = new JSONObject();
            e.put("id", id); e.put("type", "video"); e.put("mime", "video/mp4"); e.put("path", f.getAbsolutePath());
            e.put("size", f.length()); e.put("created", startedAt == 0 ? System.currentTimeMillis() : startedAt);
            e.put("name", ("dual".equals(modeNow) ? "Duo_camera_" : "Camera_") + new SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).format(new Date(System.currentTimeMillis())) + ".mp4");
            e.put("thumb", thumb == null ? "" : thumb.getAbsolutePath());
            VaultStore.add(this, activeVault, e);
        } catch (Exception ignored) {}
    }

    private File makeThumb(File f, String id) {
        MediaMetadataRetriever r = null;
        try {
            r = new MediaMetadataRetriever(); r.setDataSource(f.getAbsolutePath());
            Bitmap bmp = r.getFrameAtTime(1000000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            if (bmp == null) bmp = r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST);
            if (bmp == null) return null;
            File out = new File(VaultStore.thumbsDir(this, activeVault), id + ".jpg");
            ByteArrayOutputStream baos = new ByteArrayOutputStream(); bmp.compress(Bitmap.CompressFormat.JPEG, 78, baos);
            FileOutputStream fos = new FileOutputStream(out); fos.write(baos.toByteArray()); fos.close(); return out;
        } catch (Exception e) { return null; }
        finally { try { if (r != null) r.release(); } catch (Exception ignored) {} }
    }

    @Override public void onDestroy() { stopRecording(); super.onDestroy(); }
}
EOFJAVA



# ===== MainActivity : enregistrement plugins + verrouillage auto (sections C/D) =====
cat > "$PKG_DIR/MainActivity.java" <<'EOFJAVA'
package com.capmaster2023.admincalculator;

import android.os.Bundle;
import android.webkit.WebView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(NativeVideoPlugin.class);
        registerPlugin(LockControlPlugin.class);
        registerPlugin(VaultPlugin.class);
        registerPlugin(VaultSecurityPlugin.class);
        registerPlugin(SecurityPlugin.class);
        registerPlugin(CameraRecorderPlugin.class);
        super.onCreate(savedInstanceState);
    }

    @Override public void onUserLeaveHint() {
        if (!LockControlPlugin.isSuspended()) { LockControlPlugin.lockOnResume = true; forceCalculatorScreen(); }
        super.onUserLeaveHint();
    }
    @Override public void onPause()  { if (!LockControlPlugin.isSuspended()) { LockControlPlugin.lockOnResume = true; forceCalculatorScreen(); } super.onPause(); }
    @Override public void onStop()   { if (!LockControlPlugin.isSuspended()) { LockControlPlugin.lockOnResume = true; forceCalculatorScreen(); } super.onStop(); }
    @Override public void onResume() {
        super.onResume();
        if (LockControlPlugin.lockOnResume) { LockControlPlugin.lockOnResume = false; forceCalculatorScreen(); }
    }

    private void forceCalculatorScreen() {
        try {
            if (getBridge() == null || getBridge().getWebView() == null) return;
            final WebView webView = getBridge().getWebView();
            webView.post(() -> {
                try { webView.evaluateJavascript("location.replace('index.html')", null); } catch (Exception ignored) {}
            });
        } catch (Exception ignored) {}
    }
}
EOFJAVA

# ===== build.gradle (deps ExoPlayer) + Manifest (activités + service) =====
python3 - <<'PY3'
from pathlib import Path
import re

# --- build.gradle : ajouter media3 si absent ---
g = Path('android/app/build.gradle')
gs = g.read_text()
if 'androidx.biometric:biometric' not in gs:
    dep = '    implementation "androidx.biometric:biometric:1.1.0"\n'
    m = re.search(r'dependencies\s*\{', gs)
    if m:
        gs = gs[:m.end()] + '\n' + dep + gs[m.end():]
if 'androidx.security:security-crypto' not in gs:
    dep = '    implementation "androidx.security:security-crypto:1.0.0"\n'
    m = re.search(r'dependencies\s*\{', gs)
    if m:
        gs = gs[:m.end()] + '\n' + dep + gs[m.end():]
if 'androidx.media3:media3-exoplayer' not in gs:
    dep = ('    implementation "androidx.media3:media3-exoplayer:1.4.1"\n'
           '    implementation "androidx.media3:media3-ui:1.4.1"\n')
    m = re.search(r'dependencies\s*\{', gs)
    if m:
        gs = gs[:m.end()] + '\n' + dep + gs[m.end():]
g.write_text(gs)

# --- AndroidManifest : enregistrer activités + service ---
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text()

entries = '''        <activity android:name=".NativeVideoActivity" android:exported="false" android:configChanges="orientation|screenSize|keyboardHidden" android:screenOrientation="sensor" android:theme="@android:style/Theme.Material.NoActionBar" />
        <activity android:name=".BrowserActivity" android:exported="false" android:launchMode="singleTop" android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|smallestScreenSize" android:theme="@android:style/Theme.Material.NoActionBar" />
        <activity android:name=".DownloadsActivity" android:exported="false" android:configChanges="orientation|screenSize|keyboardHidden" android:theme="@android:style/Theme.Material.NoActionBar" />
        <service android:name=".DownloadService" android:exported="false" />
        <service android:name=".CameraRecordingService" android:exported="false" />
'''

for nm in ['.NativeVideoActivity', '.BrowserActivity', '.DownloadsActivity', '.DownloadService', '.CameraRecordingService']:
    s = re.sub(r'<(activity|service)[^>]*android:name="'+re.escape(nm)+r'"[^>]*/>\s*', '', s)
    s = re.sub(r'<(activity|service)[^>]*android:name="'+re.escape(nm)+r'"[^>]*>.*?</\1>\s*', '', s, flags=re.S)

s = s.replace('</application>', entries + '    </application>', 1)
p.write_text(s)
PY3

echo "Personnalisation Android appliquée (sans Tor, navigateur + téléchargeur intégrés, sans enregistrement d’écran)."

# ===== Protection commerciale raisonnable =====
# Active R8/ProGuard/minification pour debug + release si le projet Android est présent.
if [ -f android/app/build.gradle ]; then
  python3 - <<'PY'
from pathlib import Path
import re
p=Path('android/app/build.gradle')
s=p.read_text()

def ensure_build_type(body, name, inner):
    if re.search(r'buildTypes\s*\{', body) is None:
        return body
    if re.search(r'\b'+name+r'\s*\{', body):
        body=re.sub(r'(\b'+name+r'\s*\{)', r'\1\n            '+inner, body, count=1)
    else:
        body=re.sub(r'(buildTypes\s*\{)', r'\1\n        '+name+' {\n            '+inner+'\n        }', body, count=1)
    return body

for bt in ['debug','release']:
    if not re.search(r'\b'+bt+r'\s*\{[^}]*minifyEnabled\s+true', s, flags=re.S):
        s=ensure_build_type(s, bt, "minifyEnabled true\n            shrinkResources false\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'")
s=re.sub(r'debuggable\s+true','debuggable false',s)
p.write_text(s)
PY
  cat > android/app/proguard-rules.pro <<'PG'
# Capacitor / plugins natifs requis
-keep class com.getcapacitor.** { *; }
-keep @com.getcapacitor.annotation.CapacitorPlugin class * { *; }
-keepclassmembers class * {
    @com.getcapacitor.PluginMethod <methods>;
}
-keep class androidx.security.crypto.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.security.crypto.**
-dontwarn androidx.media3.**
-keep class org.json.** { *; }
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
}
-repackageclasses ''
-allowaccessmodification
-overloadaggressively
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
PG
fi

# ===== Aligner les packages Java natifs avec l'appId actuel =====
if [ "$APP_ID" != "com.capmaster2023.calculatrice" ]; then
  find "$APP/java" -type f -name '*.java' -print0 | xargs -0 sed -i "s/com\.capmaster2023\.calculatrice/$APP_ID/g"
fi
