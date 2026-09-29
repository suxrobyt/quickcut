#!/bin/bash
set -e
mkdir -p QuickCutAndroid/app/src/main/assets QuickCutAndroid/app/src/main/java/ai/quickcut
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
    <application android:label="QuickCut AI" android:theme="@android:style/Theme.DeviceDefault.NoActionBar" android:hardwareAccelerated="true">
        <activity android:name=".MainActivity" android:exported="true" android:configChanges="orientation|screenSize|keyboardHidden">
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
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast

class MainActivity : Activity() {
    private lateinit var web: WebView
    private var callback: ValueCallback<Array<Uri>>? = null

    inner class Bridge {
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
        web = WebView(this)
        setContentView(web)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.mediaPlaybackRequiresUserGesture = false
        web.addJavascriptInterface(Bridge(), "AndroidBridge")
        web.webViewClient = WebViewClient()
        web.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(w: WebView, cb: ValueCallback<Array<Uri>>, p: FileChooserParams): Boolean {
                callback?.onReceiveValue(null)
                callback = cb
                startActivityForResult(p.createIntent(), 1)
                return true
            }
        }
        web.loadUrl("file:///android_asset/index.html")
    }

    override fun onActivityResult(req: Int, res: Int, data: Intent?) {
        super.onActivityResult(req, res, data)
        if (req == 1) {
            callback?.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(res, data))
            callback = null
        }
    }
}
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

<div class="card"><h2>2. Uslub</h2><div class="row" id="styles"></div></div>
<div class="card"><h2>3. Format</h2><div class="row" id="ratios"></div></div>
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
let style="Fast",ratio="9:16",vids=[],imgs=[],music=null,beats=[],tl=[],seed=1,ver=1,total=15,playing=false,t0=0,raf=0,audio=new Audio(),busy=false;
const cvs=$("cv2"),ctx=cvs.getContext("2d");
function chips(el,list,cur,cb){el.innerHTML="";list.forEach(k=>{const b=document.createElement("button");b.className="chip"+(k==cur?" on":"");b.textContent=k;b.onclick=()=>{cb(k);chips(el,list,k,cb)};el.appendChild(b)})}
chips($("styles"),Object.keys(STY),style,k=>style=k);chips($("ratios"),Object.keys(RAT),ratio,k=>ratio=k);
$("th").onclick=()=>{const r=document.documentElement;r.dataset.theme=r.dataset.theme=="light"?"dark":"light"};
function load(el,tag,src){return new Promise(r=>{const e=document.createElement(tag);if(tag=="video"){e.muted=true;e.playsInline=true;e.preload="auto";e.onloadedmetadata=()=>r(e)}else e.onload=()=>r(e);e.onerror=()=>r(null);e.src=src})}
$("fv").onchange=async e=>{vids=(await Promise.all([...e.target.files].map(f=>load(0,"video",URL.createObjectURL(f))))).filter(Boolean);ui()};
$("fp").onchange=async e=>{imgs=(await Promise.all([...e.target.files].map(f=>load(0,"img",URL.createObjectURL(f))))).filter(Boolean);ui()};
$("fm").onchange=e=>{music=e.target.files[0]||null;ui()};
function ui(){$("cv").textContent=vids.length;$("cp").textContent=imgs.length;$("cm").textContent=music?1:0;
["pv","pp","pm"].forEach((id,i)=>$(id).classList.toggle("on",[vids.length,imgs.length,music][i]));
$("go").disabled=!(vids.length||imgs.length)}
function rnd(){seed=(seed*1664525+1013904223)>>>0;return seed/4294967296}
async function analyze(){
 if(!music){beats=[];total=15;return}
 const ac=new (window.AudioContext||window.webkitAudioContext)();
 const buf=await ac.decodeAudioData(await music.arrayBuffer());
 const d=buf.getChannelData(0),sr=buf.sampleRate,hop=Math.floor(sr*.03),en=[];
 for(let i=0;i+hop<d.length;i+=hop){let s=0;for(let j=0;j<hop;j+=4)s+=d[i+j]*d[i+j];en.push(s)}
 const fl=en.map((v,i)=>Math.max(0,v-(en[i-1]||0)));
 beats=[];let last=-1;
 for(let i=4;i<fl.length-4;i++){let m=0;for(let k=-20;k<=20;k++)m+=fl[i+k]||0;m/=41;
  if(fl[i]>m*1.6&&fl[i]>=fl[i-1]&&fl[i]>=fl[i+1]){const t=i*.03;if(t-last>=STY[style]){beats.push(t);last=t}}}
 total=Math.min(buf.duration,60);audio.src=URL.createObjectURL(music);ac.close();
}
function build(){
 seed=ver*7919+13;let cuts=[0];
 if(beats.length>2)beats.filter(b=>b<total).forEach(b=>cuts.push(b));else for(let t=STY[style]*3;t<total;t+=STY[style]*3)cuts.push(t);
 cuts.push(total);tl=[];let vi=0,pi=0;
 for(let i=0;i<cuts.length-1;i++){const len=cuts[i+1]-cuts[i];
  const usePhoto=imgs.length&&(!vids.length||i%3==2);
  if(usePhoto){tl.push({a:cuts[i],b:cuts[i+1],img:imgs[pi++%imgs.length],z:rnd()>.5})}
  else{const v=vids[vi++%vids.length],mx=Math.max(0,(v.duration||len)-len);tl.push({a:cuts[i],b:cuts[i+1],v,s:rnd()*mx,z:rnd()>.4,sp:style=="Cinematic"&&rnd()>.6?.6:1})}}
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
  const z=1+(c.z?p*.12:.12-p*.12)+pulse;
  if(c.v){if(cur!=i){cur=i;c.v.currentTime=c.s;c.v.playbackRate=c.sp;c.v.play().catch(()=>{})}}else if(cur!=i){cur=i;vids.forEach(v=>v.pause())}
  cover(c.v||c.img,0,0,z);
  if(style=="Cinematic"){ctx.fillStyle="rgba(0,0,0,.35)";const h=cvs.height*.08;ctx.fillRect(0,0,cvs.width,h);ctx.fillRect(0,cvs.height-h,cvs.width,h)}
  const f=Math.max(0,1-(t-c.a)*10);if(f>0){ctx.fillStyle=`rgba(255,255,255,${f*.35})`;ctx.fillRect(0,0,cvs.width,cvs.height)}}
 raf=requestAnimationFrame(frame)}
function play(from){if(!tl.length)return;cancelAnimationFrame(raf);cur=-1;
 if(from){audio.currentTime=0}t0=performance.now()-(music?0:(now()>=total?0:now()*1000));
 if(music)audio.play().catch(()=>{});playing=true;raf=requestAnimationFrame(frame)}
function stop(end){playing=false;cancelAnimationFrame(raf);audio.pause();vids.forEach(v=>v.pause());if(end&&rec)finish()}
$("play").onclick=()=>play(now()>=total-.1);$("pause").onclick=()=>stop();
$("rst").onclick=()=>{stop();audio.currentTime=0;t0=performance.now();play(true)};
async function makeVersions(){$("vers").innerHTML="";for(let k=1;k<=ver;k++){const b=document.createElement("button");b.className="chip"+(k==ver?" on":"");b.textContent="Variant "+k;b.onclick=()=>{stop();ver=k;build();play(true);makeVersions()};$("vers").appendChild(b)}}
async function run(){
 if(busy)return;busy=true;$("err").textContent="";
 const [w,h]=RAT[ratio];cvs.width=w;cvs.height=h;
 $("setup").style.display="none";$("stage").style.display="block";$("prog").style.display="block";
 const st=[["Tahlil qilinmoqda…",30],["Musiqa ritmi aniqlanmoqda…",60],["Montaj tuzilmoqda…",90]];
 $("pt").textContent=st[0][0];$("pb").style.width="30%";await new Promise(r=>setTimeout(r,200));
 try{$("pt").textContent=st[1][0];$("pb").style.width="60%";await analyze()}catch(e){music=null;audio.removeAttribute("src");total=15;$("err").textContent="Musiqani o'qib bo'lmadi, musiqasiz davom etildi."}
 $("pt").textContent=st[2][0];$("pb").style.width="90%";ver=1;build();
 $("pb").style.width="100%";$("pt").textContent="Video tayyor";
 $("note").textContent=`${tl.length} ta kesim, ${total.toFixed(0)} soniya, uslub: ${style}, ${beats.length} ta beat.`;
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
