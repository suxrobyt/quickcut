#!/bin/bash
set -e
mkdir -p QuickCutAndroid/app/src/main/assets QuickCutAndroid/app/src/main/java/ai/quickcut QuickCutAndroid/app/src/main/res/mipmap-anydpi-v26 QuickCutAndroid/app/src/main/res/drawable
cd QuickCutAndroid
cat > settings.gradle.kts <<'QCEOF'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositories { google(); mavenCentral() } }
rootProject.name = "QuickCutAI"
include(":app")
QCEOF
cat > build.gradle.kts <<'QCEOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
QCEOF
cat > gradle.properties <<'QCEOF'
-e android.useAndroidX=true
org.gradle.jvmargs=-Xmx2g
QCEOF
cat > app/build.gradle.kts <<'QCEOF'
plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "ai.quickcut"
    compileSdk = 34
    defaultConfig { applicationId = "ai.quickcut"; minSdk = 29; targetSdk = 34; versionCode = 1; versionName = "1.0.0" }
    buildTypes { release { isMinifyEnabled = false } }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
QCEOF
cat > app/src/main/AndroidManifest.xml <<'QCEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:label="QuickCut AI" android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher" android:theme="@android:style/Theme.DeviceDefault.NoActionBar" android:hardwareAccelerated="true">
        <activity android:name=".MainActivity" android:exported="true" android:configChanges="orientation|screenSize|smallestScreenSize|screenLayout|keyboard|keyboardHidden|uiMode|density|navigation|layoutDirection|fontScale|locale|colorMode">
            <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
        </activity>
    </application>
</manifest>
QCEOF
cat > app/src/main/java/ai/quickcut/MainActivity.kt <<'QCEOF'
package ai.quickcut

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import org.json.JSONArray
import java.io.File

class MainActivity : Activity() {
    private lateinit var web: WebView

    inner class Bridge {
        @JavascriptInterface
        fun pick(kind: String) {
            runOnUiThread {
                val i = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "$kind/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, kind != "audio")
                }
                startActivityForResult(i, when (kind) { "video" -> 1; "image" -> 2; else -> 3 })
            }
        }

        @JavascriptInterface
        fun save(b64: String, name: String, mime: String) {
            val v = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, name)
                put(MediaStore.Video.Media.MIME_TYPE, mime)
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/QuickCut")
            }
            val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, v)
            uri?.let { contentResolver.openOutputStream(it)?.use { o -> o.write(Base64.decode(b64, Base64.DEFAULT)) } }
            runOnUiThread { Toast.makeText(this@MainActivity, "Video galereyaga saqlandi", Toast.LENGTH_LONG).show() }
        }
    }

    override fun onCreate(s: Bundle?) {
        super.onCreate(s)
        File(cacheDir, "media").deleteRecursively()
        web = WebView(this)
        setContentView(web)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.mediaPlaybackRequiresUserGesture = false
        web.settings.allowFileAccess = true
        @Suppress("DEPRECATION")
        web.settings.allowFileAccessFromFileURLs = true
        @Suppress("DEPRECATION")
        web.settings.allowUniversalAccessFromFileURLs = true
        web.addJavascriptInterface(Bridge(), "AndroidBridge")
        web.webViewClient = WebViewClient()
        web.loadUrl("file:///android_asset/index.html")
    }

    override fun onActivityResult(req: Int, res: Int, data: Intent?) {
        super.onActivityResult(req, res, data)
        if (res != RESULT_OK || data == null) return
        val kind = when (req) { 1 -> "video"; 2 -> "image"; 3 -> "audio"; else -> return }
        val uris = mutableListOf<android.net.Uri>()
        data.clipData?.let { for (i in 0 until it.itemCount) uris.add(it.getItemAt(i).uri) }
        if (uris.isEmpty()) data.data?.let { uris.add(it) }
        Toast.makeText(this, "Fayllar yuklanmoqda...", Toast.LENGTH_SHORT).show()
        Thread {
            val out = ArrayList<String>()
            val dir = File(cacheDir, "media").apply { mkdirs() }
            uris.forEachIndexed { i, u ->
                try {
                    val def = when (kind) { "video" -> "mp4"; "image" -> "jpg"; else -> "mp3" }
                    val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(contentResolver.getType(u)) ?: def
                    val f = File(dir, "${kind}_${System.currentTimeMillis()}_$i.$ext")
                    contentResolver.openInputStream(u)?.use { inp -> f.outputStream().use { o -> inp.copyTo(o) } }
                    out.add("file://" + f.absolutePath)
                } catch (e: Exception) { }
            }
            val js = "onNative('$kind'," + JSONArray(out).toString() + ")"
            runOnUiThread { web.evaluateJavascript(js, null) }
        }.start()
    }
}
QCEOF
cat > app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml <<'QCEOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_bg"/>
    <foreground android:drawable="@drawable/ic_fg"/>
</adaptive-icon>
QCEOF
cat > app/src/main/res/drawable/ic_bg.xml <<'QCEOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#14161C" android:pathData="M0,0h108v108h-108z"/>
</vector>
QCEOF
cat > app/src/main/res/drawable/ic_fg.xml <<'QCEOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FF5A36" android:pathData="M42,32L42,76L78,54Z"/>
    <path android:fillColor="#FFD23F" android:pathData="M30,80h48v4h-48z"/>
</vector>
QCEOF
cat > app/src/main/assets/index.html <<'QCEOF'
<!DOCTYPE html>
<html lang="uz"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>QuickCut AI</title>
<style>
:root{--bg:#0f1115;--card:#1a1d24;--line:#2a2f3a;--tx:#f2f4f8;--mu:#8b93a3;--ac:#ff5a36;--ac2:#ffd23f;box-sizing:border-box;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
:root[data-theme=light]{--bg:#f5f6f8;--card:#fff;--line:#dde0e6;--tx:#14161a;--mu:#5c6472}
@media(prefers-color-scheme:light){:root:not([data-theme=dark]){--bg:#f5f6f8;--card:#fff;--line:#dde0e6;--tx:#14161a;--mu:#5c6472}}
*{box-sizing:border-box}html{scroll-padding-top:env(safe-area-inset-top,0px)}
body{margin:0;background:var(--bg);color:var(--tx);font:16px/1.45 "Trebuchet MS",system-ui,sans-serif}
main{max-width:520px;margin:0 auto;padding:18px 16px 60px}
h1{font:800 28px/1.1 "Arial Black",Impact,sans-serif;margin:6px 0 4px;letter-spacing:-.5px}
h1 b{color:var(--ac)}
p.s{color:var(--mu);margin:0 0 18px}
.top{display:flex;justify-content:space-between;align-items:center}
.card{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:14px;margin-bottom:12px}
.card h2{font-size:15px;margin:0 0 10px}
.row{display:flex;gap:8px;flex-wrap:wrap}
.pick{flex:1;min-width:96px;border:1.5px dashed var(--line);border-radius:16px;padding:14px 8px;text-align:center;cursor:pointer;color:var(--mu);font-size:14px;background:transparent}
.pick b{display:block;color:var(--tx);font-size:22px}
.pick.on{border-style:solid;border-color:var(--ac);color:var(--tx)}
.chip{border:1px solid var(--line);background:transparent;color:var(--tx);padding:9px 14px;border-radius:99px;font:inherit;font-size:14px;cursor:pointer}
.chip.on{background:var(--ac);border-color:var(--ac);color:#fff}
button:focus-visible,label:focus-within{outline:3px solid var(--ac2);outline-offset:2px}
.big{width:100%;border:0;border-radius:99px;padding:18px;font:800 18px "Arial Black",sans-serif;background:var(--ac);color:#fff;cursor:pointer}
.big:disabled{opacity:.4}
.sec{width:100%;border:1px solid var(--line);background:transparent;color:var(--tx);border-radius:99px;padding:13px;font:inherit;cursor:pointer}
input[type=file]{display:none}
.bar{height:8px;background:var(--line);border-radius:9px;overflow:hidden;margin:10px 0 4px}
.bar i{display:block;height:100%;width:0;background:linear-gradient(90deg,var(--ac),var(--ac2));transition:width .3s}
#stage{display:none}
canvas{width:100%;max-height:70vh;object-fit:contain;background:#000;border-radius:18px;display:block;margin:0 auto}
.small{color:var(--mu);font-size:13px}
.proj{display:flex;justify-content:space-between;padding:8px 0;border-top:1px solid var(--line);font-size:14px}
.proj:first-of-type{border:0}
.ver{display:flex;gap:8px;margin:10px 0}
</style></head><body><main>
<div class="top"><div><h1>Quick<b>Cut</b> AI</h1></div><button class="chip" id="th">Tema</button></div>
<p class="s">Videolaringni yukla. Qolganini AI qiladi.</p>

<section id="setup">
<div class="card"><h2>1. Fayllarni tanlang</h2>
<div class="row">
<label class="pick" id="pv"><input type="file" id="fv" accept="video/*" multiple><b id="cv">0</b>video</label>
<label class="pick" id="pp"><input type="file" id="fp" accept="image/*" multiple><b id="cp">0</b>rasm</label>
<label class="pick" id="pm"><input type="file" id="fm" accept="audio/*"><b id="cm">0</b>musiqa</label>
</div><p class="small" style="margin:10px 0 0">Fayllar telefondan chiqmaydi: hammasi shu qurilmada qayta ishlanadi.</p></div>

<div class="card"><h2>Montaj ko'rsatmasi (o'zbekcha)</h2><textarea id="ins" rows="3" placeholder="Masalan: tez va kulgili montaj, 30 soniya, rasmlar oxirida, yozuv: Yozgi sayohat" style="width:100%;padding:12px;border-radius:12px;border:1px solid var(--line);background:transparent;color:var(--tx);font:inherit"></textarea><input id="key" type="password" placeholder="AI kaliti (Gemini: AIza... yoki Claude: sk-ant-...)" style="width:100%;margin-top:8px;padding:12px;border-radius:12px;border:1px solid var(--line);background:transparent;color:var(--tx);font:inherit"><p class="small" style="margin:8px 0 0">AI videolaringizni ko'rib, ko'rsatmangizga qarab montaj rejasini tuzadi. Bepul kalit: aistudio.google.com/apikey. Kalit faqat shu telefonda saqlanadi. Kalitsiz oddiy so'z tahlili ishlaydi.</p></div>
<div class="card"><h2>Shablonlar</h2><div class="row" id="tpl"></div></div>
<div class="card"><h2>2. Uslub</h2><div class="row" id="styles"></div></div>
<div class="card"><h2>3. Format</h2><div class="row" id="ratios"></div></div>
<div class="card"><h2>4. Qo'shimcha</h2><input id="tx" placeholder="Video ustiga yozuv (ixtiyoriy)" style="width:100%;padding:12px;border-radius:12px;border:1px solid var(--line);background:transparent;color:var(--tx);font:inherit"><p class="small" style="margin:12px 0 4px">Musiqa ovozi</p><input type="range" id="vol" min="0" max="1" step=".05" value="1" style="width:100%"></div>
<button class="big" id="go" disabled>AI MONTAJ</button>
<div id="err" class="small" style="color:var(--ac);margin-top:8px"></div>

<div class="card" style="margin-top:16px"><h2>Loyihalarim</h2><div id="projs" class="small">Hali loyiha yo'q. Birinchi videoni yarating.</div></div>
</section>

<section id="stage">
<div id="prog"><b id="pt">Tayyorlanmoqda…</b><div class="bar"><i id="pb"></i></div></div>
<canvas id="cv2" width="540" height="960"></canvas>
<div class="ver" id="vers"></div>
<div class="row" style="margin-top:6px">
<button class="chip" id="play">Ijro</button><button class="chip" id="pause">Pauza</button><button class="chip" id="rst">Boshidan</button>
</div>
<div style="display:grid;gap:8px;margin-top:14px">
<button class="big" id="exp">MP4/WEBM EKSPORT</button>
<button class="sec" id="reg">Qayta yaratish</button>
<button class="sec" id="back">Yangi loyiha</button>
</div>
<p class="small" id="note"></p>
</section>
</main>
<script>
const $=id=>document.getElementById(id);
const STY={Fast:.3,Gaming:.35,Meme:.4,"Beat Sync":.45,Smooth:.7,Cinematic:1}, RAT={"9:16":[540,960],"16:9":[960,540],"1:1":[720,720],"4:5":[640,800]};
let IN={},style="Fast",ratio="9:16",vids=[],imgs=[],music=null,beats=[],tl=[],seed=1,ver=1,total=15,playing=false,t0=0,raf=0,audio=new Audio(),busy=false;
const cvs=$("cv2"),ctx=cvs.getContext("2d");
function chips(el,list,cur,cb){el.innerHTML="";list.forEach(k=>{const b=document.createElement("button");b.className="chip"+(k==cur?" on":"");b.textContent=k;b.onclick=()=>{cb(k);chips(el,list,k,cb)};el.appendChild(b)})}
const rs=()=>chips($("styles"),Object.keys(STY),style,k=>style=k),rr=()=>chips($("ratios"),Object.keys(RAT),ratio,k=>ratio=k);rs();rr();
const TPL=[["Tez montaj","Fast","9:16"],["Beat Sync","Beat Sync","9:16"],["Meme","Meme","9:16"],["Gaming","Gaming","9:16"],["TikTok","Fast","9:16"],["Kino","Cinematic","16:9"]];
const tn=TPL.map(t=>t[0]),tp=c=>chips($("tpl"),tn,c,k=>{const t=TPL.find(x=>x[0]==k);style=t[1];ratio=t[2];rs();rr();tp(k)});tp("");
$("th").onclick=()=>{const r=document.documentElement;r.dataset.theme=r.dataset.theme=="light"?"dark":"light"};
function load(el,tag,src){return new Promise(r=>{const e=document.createElement(tag);if(tag=="video"){e.muted=true;e.playsInline=true;e.preload="auto";e.onloadedmetadata=()=>r(e)}else e.onload=()=>r(e);e.onerror=()=>r(null);e.src=src})}
$("fv").onchange=async e=>{vids=(await Promise.all([...e.target.files].map(f=>load(0,"video",URL.createObjectURL(f))))).filter(Boolean);ui()};
$("fp").onchange=async e=>{imgs=(await Promise.all([...e.target.files].map(f=>load(0,"img",URL.createObjectURL(f))))).filter(Boolean);ui()};
$("fm").onchange=e=>{music=e.target.files[0]||null;ui()};
function xhr(u){return new Promise((r,j)=>{const x=new XMLHttpRequest();x.open("GET",u);x.responseType="arraybuffer";x.onload=()=>r(x.response);x.onerror=j;x.send()})}
window.onNative=async(k,u)=>{$("err").textContent="";let a=[];
 if(k=="video"){a=(await Promise.all(u.map(x=>load(0,"video",x)))).filter(Boolean);vids=vids.concat(a)}
 else if(k=="image"){a=(await Promise.all(u.map(x=>load(0,"img",x)))).filter(Boolean);imgs=imgs.concat(a)}
 else if(u.length){music={url:u[0]};a=[1]}
 if(!a.length)$("err").textContent="Fayl o'qilmadi. Boshqa fayl tanlab ko'ring.";ui()};
[["pv","video"],["pp","image"],["pm","audio"]].forEach(([id,k])=>$(id).addEventListener("click",e=>{if(window.AndroidBridge){e.preventDefault();AndroidBridge.pick(k)}}));
function parse(T0){const t=(T0||"").toLowerCase().replace(/[ʻʼ‘’`´]/g,"'"),o={sum:[]},m=r=>t.match(r);
 for(const [r,n] of [[/kino|kinematik|cinematic/,"Cinematic"],[/silliq|yumshoq/,"Smooth"],[/o'yin|gaming|gameplay/,"Gaming"],[/kulgili|meme|hazil/,"Meme"],[/beat|ritm/,"Beat Sync"],[/tez|dinamik|energiya/,"Fast"]])if(r.test(t)){o.style=n;o.sum.push("uslub "+n);break}
 for(const [r,n] of [[/9:16|shorts|tiktok|reels|vertikal/,"9:16"],[/16:9|youtube|gorizontal/,"16:9"],[/1:1|kvadrat/,"1:1"],[/4:5/,"4:5"]])if(r.test(t)){o.ratio=n;o.sum.push("format "+n);break}
 let x=m(/(\d+)\s*(soniya|sekund|sek|minut|daqiqa)/);if(x){o.dur=+x[1]*(/min|daq/.test(x[2])?60:1);o.sum.push(o.dur+" soniya")}
 x=m(/har\s*(\d+(?:[.,]\d+)?)\s*(?:soniya|sekund|sek)/);if(x){o.gap=parseFloat(x[1].replace(",","."));o.sum.push("har "+o.gap+" s kesim")}
 x=(T0||"").match(/["«]([^"»]+)["»]/)||(T0||"").match(/yozuv[:\s]+(.+)/i);if(x){o.txt=x[1].trim();o.sum.push("yozuv")}
 if(/rasm\S*\s*(?:avval|boshida|birinchi)/.test(t)){o.ph="first";o.sum.push("rasmlar boshida")}else if(/rasm\S*\s*(?:oxirida|oxirgi)/.test(t)){o.ph="end";o.sum.push("rasmlar oxirida")}
 if(/sekin harakat|slow/.test(t)){o.slow=1;o.sum.push("sekin harakat")}
 if(/zoomsiz|zoom\s*(?:yo'q|kerak emas|qo'shma)/.test(t)){o.noZoom=1;o.sum.push("zoomsiz")}
 if(/ovozsiz|musiqa ovozini o'chir/.test(t))o.vol=0;else if(/musiqa\s*(?:past|sekin)/.test(t))o.vol=.3;else if(/musiqa\s*baland/.test(t))o.vol=1;
 return o}
const SYS=`Sen video montaj rejalashtiruvchisan. Foydalanuvchi o'zbekcha ko'rsatma beradi. FAQAT JSON qaytar, boshqa hech narsa yozma: {"style":"Fast|Gaming|Meme|Beat Sync|Smooth|Cinematic","ratio":"9:16|16:9|1:1|4:5","dur":son yoki null,"gap":har bir kesim soniyasi yoki null,"txt":ekran yozuvi yoki null,"photos":"first|end|mix","slow":true|false,"noZoom":true|false,"vol":0..1 yoki null,"order":[videolar tartibi, 1 dan boshlab, hammasi] yoki null,"speeds":[har video tezligi 0.5..2, asl tartibda] yoki null,"say":"nima qilganing haqida bitta qisqa o'zbekcha jumla"}. Berilgan kadrlar video va rasmlar mazmunini ko'rsatadi: ularga qarab eng yaxshi tartib va uslubni tanla.`;
function snap(v){return new Promise(res=>{const W=256,iw=v.videoWidth||v.naturalWidth||16,ih=v.videoHeight||v.naturalHeight||9,c=document.createElement("canvas");c.width=W;c.height=Math.round(W*ih/iw);
 const done=()=>{v.onseeked=null;try{c.getContext("2d").drawImage(v,0,0,c.width,c.height);res(c.toDataURL("image/jpeg",.6).split(",")[1])}catch(e){res(null)}};
 if(v.tagName=="VIDEO"){v.onseeked=done;v.currentTime=(v.duration||1)*.3;setTimeout(done,2500)}else done()})}
function applyPlan(J){const o={sum:[]};
 if(STY[J.style])o.style=J.style;if(RAT[J.ratio])o.ratio=J.ratio;
 if(+J.dur>0)o.dur=+J.dur;if(+J.gap>0)o.gap=+J.gap;if(J.txt)o.txt=String(J.txt);
 if(J.photos=="first"||J.photos=="end")o.ph=J.photos;
 o.slow=!!J.slow;o.noZoom=!!J.noZoom;
 if(J.vol!=null&&isFinite(J.vol))o.vol=Math.max(0,Math.min(1,+J.vol));
 vids.forEach((v,i)=>{const x=Array.isArray(J.speeds)?+J.speeds[i]:0;v._sp=x>=.5&&x<=2?x:undefined});
 if(Array.isArray(J.order)&&J.order.length==vids.length){const ix=J.order.map(n=>n-1);if(new Set(ix).size==vids.length&&ix.every(n=>n>=0&&n<vids.length))vids=ix.map(n=>vids[n])}
 if(J.say)o.sum.push("AI: "+J.say);return o}
let GM=null;
async function gem(k,c){const H={"x-goog-api-key":k,"content-type":"application/json"},B="https://generativelanguage.googleapis.com/v1beta/";
 if(!GM){let ms=[];try{const r=await fetch(B+"models?pageSize=200",{headers:H}),j=await r.json();if(j.error)throw new Error(j.error.message);ms=(j.models||[]).filter(x=>(x.supportedGenerationMethods||[]).includes("generateContent")).map(x=>x.name.replace("models/",""))}catch(e){if(/key|permission|country|billing/i.test(e.message))throw e}
  const v=n=>parseFloat((n.match(/gemini-([\d.]+)/)||[0,0])[1]),f=ms.filter(n=>/^gemini-[\d.]+-flash$/.test(n)).sort((a,b)=>v(b)-v(a));
  GM=f[0]||ms.filter(n=>/flash/.test(n)&&!/image|tts|live|audio|lite/.test(n)).sort((a,b)=>v(b)-v(a))[0]||"gemini-2.5-flash"}
 const parts=c.map(x=>x.type=="text"?{text:x.text}:{inlineData:{mimeType:"image/jpeg",data:x.source.data}});
 const r=await fetch(B+"models/"+GM+":generateContent",{method:"POST",headers:H,body:JSON.stringify({systemInstruction:{parts:[{text:SYS}]},contents:[{role:"user",parts}],generationConfig:{responseMimeType:"application/json",maxOutputTokens:800}})});
 const j=await r.json();if(j.error){GM=null;throw new Error(j.error.message)}
 return((j.candidates||[])[0]?.content?.parts||[]).map(x=>x.text||"").join("")}
async function plan(){const t=$("ins").value.trim(),k=$("key").value.trim();
 try{if(k)localStorage.setItem("qk",k)}catch(e){}
 if(!t)return{sum:[]};
 if(!k){const o=parse(t);o.warn=" AI kaliti kiritilmagan, oddiy tahlil ishlatildi.";return o}
 $("go").textContent="AI ko'rmoqda va o'ylamoqda…";
 try{const c=[];
  for(let i=0;i<Math.min(vids.length,6);i++){const d=await snap(vids[i]);c.push({type:"text",text:"Video "+(i+1)+" ("+Math.round(vids[i].duration)+" s):"});if(d)c.push({type:"image",source:{type:"base64",media_type:"image/jpeg",data:d}})}
  for(let i=0;i<Math.min(imgs.length,4);i++){const d=await snap(imgs[i]);c.push({type:"text",text:"Rasm "+(i+1)+":"});if(d)c.push({type:"image",source:{type:"base64",media_type:"image/jpeg",data:d}})}
  c.push({type:"text",text:"Jami: "+vids.length+" video, "+imgs.length+" rasm, musiqa: "+(music?"bor":"yo'q")+".\nKo'rsatma: "+t});
  let tx;if(k.startsWith("AIza"))tx=await gem(k,c);else{const r=await fetch("https://api.anthropic.com/v1/messages",{method:"POST",headers:{"content-type":"application/json","x-api-key":k,"anthropic-version":"2023-06-01","anthropic-dangerous-direct-browser-access":"true"},body:JSON.stringify({model:"claude-haiku-4-5-20251001",max_tokens:600,system:SYS,messages:[{role:"user",content:c}]})});
   const j=await r.json();if(j.error)throw new Error(j.error.message);tx=j.content.map(x=>x.text||"").join("")}
  return applyPlan(JSON.parse(tx.slice(tx.indexOf("{"),tx.lastIndexOf("}")+1)))
 }catch(e){const o=parse(t);o.warn=" AI ishlamadi ("+e.message+"), oddiy tahlil ishlatildi.";return o}
 finally{$("go").textContent="AI MONTAJ"}}
try{$("key").value=localStorage.getItem("qk")||""}catch(e){}
function ui(){$("cv").textContent=vids.length;$("cp").textContent=imgs.length;$("cm").textContent=music?1:0;
["pv","pp","pm"].forEach((id,i)=>$(id).classList.toggle("on",[vids.length,imgs.length,music][i]));
$("go").disabled=!(vids.length||imgs.length)}
function rnd(){seed=(seed*1664525+1013904223)>>>0;return seed/4294967296}
async function analyze(){
 if(!music){beats=[];total=IN.dur||15;return}
 const ac=new (window.AudioContext||window.webkitAudioContext)();
 const buf=await ac.decodeAudioData(await (music.arrayBuffer?music.arrayBuffer():xhr(music.url)));
 const d=buf.getChannelData(0),sr=buf.sampleRate,hop=Math.floor(sr*.03),en=[];
 for(let i=0;i+hop<d.length;i+=hop){let s=0;for(let j=0;j<hop;j+=4)s+=d[i+j]*d[i+j];en.push(s)}
 const fl=en.map((v,i)=>Math.max(0,v-(en[i-1]||0)));
 beats=[];let last=-1;
 for(let i=4;i<fl.length-4;i++){let m=0;for(let k=-20;k<=20;k++)m+=fl[i+k]||0;m/=41;
  if(fl[i]>m*1.6&&fl[i]>=fl[i-1]&&fl[i]>=fl[i+1]){const t=i*.03;if(t-last>=(IN.gap||STY[style])){beats.push(t);last=t}}}
 total=Math.min(buf.duration,IN.dur||60);audio.src=music.url||URL.createObjectURL(music);ac.close();
}
function build(){
 seed=ver*7919+13;let cuts=[0];
 if(beats.length>2)beats.filter(b=>b<total).forEach(b=>cuts.push(b));else{const g=IN.gap||STY[style]*3;for(let t=g;t<total;t+=g)cuts.push(t)}
 cuts.push(total);tl=[];let vi=0,pi=0;
 for(let i=0;i<cuts.length-1;i++){const len=cuts[i+1]-cuts[i];
  const n=cuts.length-1,usePhoto=imgs.length&&(!vids.length||(IN.ph=="first"?i<imgs.length:IN.ph=="end"?i>=n-imgs.length:i%3==2));
  if(usePhoto){tl.push({a:cuts[i],b:cuts[i+1],img:imgs[pi++%imgs.length],z:rnd()>.5})}
  else{const v=vids[vi++%vids.length],mx=Math.max(0,(v.duration||len)-len);tl.push({a:cuts[i],b:cuts[i+1],v,s:rnd()*mx,z:rnd()>.4,sp:v._sp||(((style=="Cinematic"&&rnd()>.6)||IN.slow)?.6:1)})}}
}
function cover(src,w,h,z){const sw=src.videoWidth||src.naturalWidth,sh=src.videoHeight||src.naturalHeight;if(!sw)return;
 let s=Math.max(cvs.width/sw,cvs.height/sh)*z;ctx.drawImage(src,(cvs.width-sw*s)/2,(cvs.height-sh*s)/2,sw*s,sh*s)}
let cur=-1;
function now(){return audio.src&&music?audio.currentTime:(performance.now()-t0)/1000}
function frame(){
 const t=now();ctx.fillStyle="#000";ctx.fillRect(0,0,cvs.width,cvs.height);
 const i=tl.findIndex(x=>t>=x.a&&t<x.b);
 if(i<0){if(t>=total-.05){stop(true);return}}
 else{const c=tl[i],p=(t-c.a)/(c.b-c.a),pulse=Math.max(0,1-(t-c.a)*6)*.08;
  const z=IN.noZoom?1:1+(c.z?p*.12:.12-p*.12)+pulse;
  if(c.v){if(cur!=i){cur=i;c.v.currentTime=c.s;c.v.playbackRate=c.sp;c.v.play().catch(()=>{})}}else if(cur!=i){cur=i;vids.forEach(v=>v.pause())}
  cover(c.v||c.img,0,0,z);
  if(style=="Cinematic"){ctx.fillStyle="rgba(0,0,0,.35)";const h=cvs.height*.08;ctx.fillRect(0,0,cvs.width,h);ctx.fillRect(0,cvs.height-h,cvs.width,h)}
  const f=Math.max(0,1-(t-c.a)*10);if(f>0){ctx.fillStyle=`rgba(255,255,255,${f*.35})`;ctx.fillRect(0,0,cvs.width,cvs.height)}}
 const T=$("tx").value;if(T){ctx.font="800 "+cvs.width*.06+"px sans-serif";ctx.textAlign="center";ctx.lineWidth=6;ctx.strokeStyle="#000";const y=cvs.height*.86;ctx.strokeText(T,cvs.width/2,y,cvs.width*.9);ctx.fillStyle="#fff";ctx.fillText(T,cvs.width/2,y,cvs.width*.9)}
 raf=requestAnimationFrame(frame)}
function play(from){if(!tl.length)return;cancelAnimationFrame(raf);cur=-1;
 if(from){audio.currentTime=0}t0=performance.now()-(music?0:(now()>=total?0:now()*1000));
 audio.volume=+$("vol").value;if(music)audio.play().catch(()=>{});playing=true;raf=requestAnimationFrame(frame)}
function stop(end){playing=false;cancelAnimationFrame(raf);audio.pause();vids.forEach(v=>v.pause());if(end&&rec)finish()}
$("play").onclick=()=>play(now()>=total-.1);$("pause").onclick=()=>stop();
$("rst").onclick=()=>{stop();audio.currentTime=0;t0=performance.now();play(true)};
async function makeVersions(){$("vers").innerHTML="";for(let k=1;k<=ver;k++){const b=document.createElement("button");b.className="chip"+(k==ver?" on":"");b.textContent="Variant "+k;b.onclick=()=>{stop();ver=k;build();play(true);makeVersions()};$("vers").appendChild(b)}}
async function run(){
 if(busy)return;busy=true;$("err").textContent="";IN=await plan();if(IN.style)style=IN.style;if(IN.ratio)ratio=IN.ratio;if(IN.txt)$("tx").value=IN.txt;if(IN.vol!=null)$("vol").value=IN.vol;
 const [w,h]=RAT[ratio];cvs.width=w;cvs.height=h;
 $("setup").style.display="none";$("stage").style.display="block";$("prog").style.display="block";
 const st=[["Tahlil qilinmoqda…",30],["Musiqa ritmi aniqlanmoqda…",60],["Montaj tuzilmoqda…",90]];
 $("pt").textContent=st[0][0];$("pb").style.width="30%";await new Promise(r=>setTimeout(r,200));
 try{$("pt").textContent=st[1][0];$("pb").style.width="60%";await analyze()}catch(e){music=null;audio.removeAttribute("src");total=15;$("err").textContent="Musiqani o'qib bo'lmadi, musiqasiz davom etildi."}
 $("pt").textContent=st[2][0];$("pb").style.width="90%";ver=1;build();
 $("pb").style.width="100%";$("pt").textContent="Video tayyor";
 $("note").textContent=`${tl.length} ta kesim, ${total.toFixed(0)} soniya, uslub: ${style}, ${beats.length} ta beat.${IN.sum&&IN.sum.length?" Tushunildi: "+IN.sum.join(", ")+".":""}${IN.warn||""}`;
 saveProj();makeVersions();play(true);busy=false}
$("go").onclick=run;
$("reg").onclick=()=>{stop();ver++;seed=ver*7919+13;build();makeVersions();play(true)};
$("back").onclick=()=>{stop();$("stage").style.display="none";$("setup").style.display="block"};
let rec=null,chunks=[];
$("exp").onclick=()=>{stop();$("exp").disabled=true;$("exp").textContent="Render qilinmoqda…";
 const cs=cvs.captureStream(30);
 try{if(music){const as=audio.captureStream?audio.captureStream():null;if(as)as.getAudioTracks().forEach(t=>cs.addTrack(t))}}catch(e){}
 const mt=["video/mp4;codecs=avc1","video/mp4","video/webm;codecs=vp9,opus","video/webm"].find(m=>MediaRecorder.isTypeSupported(m));
 if(!mt){$("note").textContent="Bu brauzer eksportni qo'llamaydi. Chrome yoki Safari'da oching.";$("exp").disabled=false;$("exp").textContent="EKSPORT";return}
 chunks=[];rec=new MediaRecorder(cs,{mimeType:mt,videoBitsPerSecond:6e6});rec.ondataavailable=e=>chunks.push(e.data);
 rec.onstop=()=>{const ext=mt.includes("mp4")?"mp4":"webm",bl=new Blob(chunks,{type:mt});if(window.AndroidBridge){const fr=new FileReader();fr.onload=()=>AndroidBridge.save(fr.result.split(",")[1],"quickcut_"+Date.now()+"."+ext,mt.split(";")[0]);fr.readAsDataURL(bl)}else{const a=document.createElement("a");a.href=URL.createObjectURL(bl);a.download="quickcut."+ext;a.click()};rec=null;$("exp").disabled=false;$("exp").textContent="MP4/WEBM EKSPORT";$("note").textContent="Video tayyor. Eksport tugadi."};
 rec.start();audio.currentTime=0;t0=performance.now();play(true)};
function finish(){setTimeout(()=>rec&&rec.stop(),300)}
function saveProj(){let p=JSON.parse(localStorage.getItem("qc")||"[]");try{p.unshift({n:"Loyiha "+(p.length+1),d:new Date().toLocaleDateString(),s:Math.round(total)+" s",st:"Tayyor"});localStorage.setItem("qc",JSON.stringify(p.slice(0,8)))}catch(e){}showProj()}
function showProj(){let p=[];try{p=JSON.parse(localStorage.getItem("qc")||"[]")}catch(e){}
 if(p.length)$("projs").innerHTML=p.map(x=>`<div class="proj"><span>${x.n}, ${x.d}</span><span>${x.s}, ${x.st}</span></div>`).join("")}
showProj();
</script></body></html>
QCEOF
