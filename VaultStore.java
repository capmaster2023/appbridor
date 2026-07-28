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