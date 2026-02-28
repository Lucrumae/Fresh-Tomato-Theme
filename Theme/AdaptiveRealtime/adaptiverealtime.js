/* adaptiverealtime.js — FreshTomato Realtime Adaptive Theme
   - Default: muted sampai user aktifkan
   - Popup "click anywhere to unmute" saat audio pernah ON
   - requestAnimationFrame + throttle 100ms
   - sessionStorage cache anti-flicker
   - Controls proximity 80px pojok kanan bawah
*/
(function () {

    var vidStyle = document.createElement('style');
    vidStyle.textContent =
        '#bg-video{position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:-1;object-fit:cover;object-position:center center;pointer-events:none;}' +
        '*{transition:background-color 0.8s ease,border-color 0.8s ease,color 0.8s ease!important;}' +
        'a,input,select,textarea,button{transition-duration:0.15s!important;}';
    document.head.appendChild(vidStyle);

    var vid = document.createElement('video');
    vid.id='bg-video'; vid.autoplay=vid.loop=vid.muted=vid.playsInline=true;
    vid.setAttribute('playsinline',''); vid.crossOrigin='anonymous';
    var src = document.createElement('source');
    src.src='/bgmp4.gif'; src.type='video/mp4';
    vid.appendChild(src);

    function rgbToHsl(r,g,b){r/=255;g/=255;b/=255;var max=Math.max(r,g,b),min=Math.min(r,g,b),h,s,l=(max+min)/2;if(max===min){h=s=0;}else{var d=max-min;s=l>0.5?d/(2-max-min):d/(max+min);switch(max){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;break;}}return[h*360,s*100,l*100];}
    function hslToRgb(h,s,l){h/=360;s/=100;l/=100;var r,g,b;if(s===0){r=g=b=l;}else{var q=l<0.5?l*(1+s):l+s-l*s,p=2*l-q;function hue2rgb(t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<0.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}r=hue2rgb(h+1/3);g=hue2rgb(h);b=hue2rgb(h-1/3);}return[Math.round(r*255),Math.round(g*255),Math.round(b*255)];}
    function relLum(r,g,b){function lin(c){c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);}return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b);}
    function cr(l1,l2){var a=Math.max(l1,l2),b=Math.min(l1,l2);return(a+0.05)/(b+0.05);}
    function bestText(r,g,b){return cr(1.0,relLum(r,g,b))>=cr(0.0,relLum(r,g,b))?[255,255,255]:[0,0,0];}
    function ensureContrast(fr,fg,fb,br,bg,bb,min){min=min||4.5;var bl=relLum(br,bg,bb);if(cr(relLum(fr,fg,fb),bl)>=min)return[fr,fg,fb];var hsl=rgbToHsl(fr,fg,fb),h=hsl[0],s=hsl[1],l=hsl[2],rgb;for(var li=l;li<=98;li+=2){rgb=hslToRgb(h,s,li);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}for(var ld=l;ld>=2;ld-=2){rgb=hslToRgb(h,s,ld);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}return bestText(br,bg,bb);}
    function rgb(c){return"rgb("+c[0]+","+c[1]+","+c[2]+")";}
    function rgba(c,a){return"rgba("+c[0]+","+c[1]+","+c[2]+","+a+")";}
    function set(k,v){document.documentElement.style.setProperty(k,v);}
    function applyPalette(r,g,b){var hsl=rgbToHsl(r,g,b),hue=hsl[0],sat=hsl[1],lum=hsl[2];var isDark=lum<50;var sat2=Math.max(sat,50);var pL=isDark?Math.min(lum+10,25):Math.max(lum-10,75);var hL=isDark?Math.min(lum+5,18):Math.max(lum-5,82);var panelRgb=hslToRgb(hue,Math.min(sat2,45),pL);var headerRgb=hslToRgb(hue,Math.min(sat2,50),hL);var accentRgb=hslToRgb(hue,Math.max(sat2,60),isDark?70:40);var accent2=hslToRgb((hue+30)%360,Math.max(sat2,55),isDark?75:35);var accentHl=hslToRgb(hue,Math.max(sat2,50),isDark?88:25);var bgFb=hslToRgb(hue,Math.min(sat,35),isDark?8:92);var eBgR=Math.round(panelRgb[0]*0.28+bgFb[0]*0.72);var eBgG=Math.round(panelRgb[1]*0.28+bgFb[1]*0.72);var eBgB=Math.round(panelRgb[2]*0.28+bgFb[2]*0.72);var tP=ensureContrast(isDark?250:15,isDark?245:10,isDark?235:8,eBgR,eBgG,eBgB,5.0);var tS=ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);var tV=ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);var aSec=ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);var aHl=ensureContrast(accentHl[0],accentHl[1],accentHl[2],eBgR,eBgG,eBgB,3.5);var logB=isDark?[255,250,235]:[10,6,3];var logC=bestText(logB[0],logB[1],logB[2]);var inpB=hslToRgb(hue,Math.min(sat*0.25,12),isDark?94:10);var inpC=bestText(inpB[0],inpB[1],inpB[2]);var prog=hslToRgb((hue+15)%360,Math.max(sat2,65),isDark?72:38);var svgT=ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);set("--bg-fallback",rgb(bgFb));set("--panel-bg",rgba(panelRgb,0.28));set("--header-bg",rgba(headerRgb,0.60));set("--log-bg",rgb(logB));set("--bwm-bg",rgba(panelRgb,0.07));set("--tab-bg",rgba(headerRgb,0.35));set("--text-primary",rgb(tP));set("--text-secondary",rgb(tS));set("--text-value",rgb(tV));set("--log-color",rgb(logC));set("--tab-text",rgb(tP));set("--accent-primary",rgba(accentRgb,0.22));set("--accent-secondary",rgb(aSec));set("--accent-highlight",rgb(aHl));set("--link-color",rgb(tS));set("--link-hover-color",rgb(aHl));set("--btn-bg",rgba(accentRgb,0.22));set("--btn-color",rgb(tP));set("--progress-color",rgb(prog));set("--input-bg",rgba(inpB,0.85));set("--input-color",rgb(inpC));set("--input-border",rgba(accentRgb,0.25));set("--svg-text-color",rgb(svgT));set("--svg-grid-stroke",rgba(accentRgb,0.15));set("--bwm-border",rgba(accentRgb,0.18));set("--svg-bg",rgba(headerRgb,0.30));set("--tab-active-bg",rgba(accentRgb,0.20));set("--row-even",rgba(accentRgb,0.06));set("--row-odd",rgba(accentRgb,0.02));set("--scrollbar-track",rgba(accentRgb,0.05));set("--scrollbar-thumb",rgba(accentRgb,0.40));set("--scrollbar-hover",rgba(accentRgb,0.65));document.documentElement.style.backgroundColor=rgb(bgFb);}

    var CACHE_KEY_RT="ft_palette_rt";
    try{var cached=sessionStorage.getItem(CACHE_KEY_RT);if(cached){var c=cached.split(",");applyPalette(parseInt(c[0]),parseInt(c[1]),parseInt(c[2]));}}catch(e){}
    var canvas=document.createElement("canvas");canvas.width=64;canvas.height=36;
    var ctx=canvas.getContext("2d");
    var lastHue=-1,lastSample=0,THROTTLE=100,HUE_THRESHOLD=5;
    function sample(){if(vid.readyState<2)return;try{ctx.drawImage(vid,0,0,64,36);var px=ctx.getImageData(0,0,64,36).data,r=0,g=0,b=0,n=0;for(var i=0;i<px.length;i+=4){var pr=px[i],pg=px[i+1],pb=px[i+2],br=(pr+pg+pb)/3;if(br<15||br>240)continue;r+=pr;g+=pg;b+=pb;n++;}if(n===0)return;r=Math.round(r/n);g=Math.round(g/n);b=Math.round(b/n);var hsl=rgbToHsl(r,g,b),hue=hsl[0];if(lastHue>=0){var diff=Math.abs(hue-lastHue);if(diff>180)diff=360-diff;if(diff<HUE_THRESHOLD)return;}lastHue=hue;applyPalette(r,g,b);try{sessionStorage.setItem(CACHE_KEY_RT,r+","+g+","+b);}catch(e){}}catch(e){}}
    function loop(ts){if(ts-lastSample>=THROTTLE){lastSample=ts;sample();}requestAnimationFrame(loop);}
    function startLoop(){requestAnimationFrame(loop);}
    if(vid.readyState>=2){startLoop();}
    else{vid.addEventListener("loadeddata",startLoop,{once:true});vid.addEventListener("canplay",startLoop,{once:true});vid.addEventListener("playing",startLoop,{once:true});}

    // ── AUTOPLAY + AUDIO UNLOCK ────────────────────────────
    // Default: muted=true (sampai user aktifkan)
    // Popup "click anywhere to unmute" muncul jika audio pernah ON
    // dan hilang saat user klik atau setelah 5 detik

    var MUTE_KEY  = 'ft_bg_muted';
    var PANEL_KEY = 'ft_panel_hidden';

    // Pertama kali install → null → default muted
    var isMuted       = localStorage.getItem(MUTE_KEY)  !== 'false';
    var isPanelHidden = localStorage.getItem(PANEL_KEY) === 'true';

    function startVideo(){
        vid.muted = true; // selalu start muted agar autoplay tidak diblokir
        vid.play().catch(function(){
            // Benar-benar diblokir — tunggu interaksi apapun
            ['click','touchstart','keydown'].forEach(function(e){
                document.addEventListener(e, function once(){
                    document.removeEventListener(e, once);
                    vid.play().catch(function(){});
                }, {once:true});
            });
        });
    }

    function showUnmutePopup(){
        // Jangan tampilkan jika user memang pilih mute
        if(localStorage.getItem(MUTE_KEY) === 'true') return;
        // Jangan tampilkan jika sudah ada
        if(document.getElementById('ft-unmute-popup')) return;

        var pStyle = document.createElement('style');
        pStyle.textContent =
            '#ft-unmute-popup{' +
                'position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(0);' +
                'z-index:99999;' +
                'background:rgba(10,10,10,0.82);' +
                'backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);' +
                'color:#fff;font-size:13px;font-family:sans-serif;' +
                'padding:10px 22px;border-radius:24px;' +
                'box-shadow:0 4px 16px rgba(0,0,0,0.5);' +
                'cursor:pointer;white-space:nowrap;' +
                'display:flex;align-items:center;gap:8px;' +
                'animation:ft-popup-in 0.3s ease;' +
            '}' +
            '@keyframes ft-popup-in{' +
                'from{opacity:0;transform:translateX(-50%) translateY(12px);}' +
                'to{opacity:1;transform:translateX(-50%) translateY(0);}' +
            '}' +
            '#ft-unmute-popup.ft-popup-out{' +
                'animation:ft-popup-out 0.3s ease forwards;' +
            '}' +
            '@keyframes ft-popup-out{' +
                'from{opacity:1;transform:translateX(-50%) translateY(0);}' +
                'to{opacity:0;transform:translateX(-50%) translateY(12px);}' +
            '}';
        document.head.appendChild(pStyle);

        var popup = document.createElement('div');
        popup.id = 'ft-unmute-popup';
        popup.innerHTML =
            '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
                '<path d="M11 5L6 9H2v6h4l5 4V5z"/>' +
                '<path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>' +
                '<path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>' +
            '</svg>' +
            'Click anywhere to unmute';

        function dismissPopup(unmute){
            if(!popup.parentNode) return;
            popup.classList.add('ft-popup-out');
            setTimeout(function(){
                if(popup.parentNode) popup.parentNode.removeChild(popup);
                if(pStyle.parentNode) pStyle.parentNode.removeChild(pStyle);
            }, 300);
            if(unmute){
                vid.muted = false;
                isMuted = false;
                localStorage.setItem(MUTE_KEY, 'false');
                // Set flag hanya di router page — di login page tidak perlu
                var isLoginPage = window.location.pathname.indexOf('login') !== -1;
                if(!isLoginPage) sessionStorage.setItem('ft_session_unmuted', '1');
                // Sync tombol mute jika sudah ada
                var btn = document.getElementById('ft-btn-mute');
                if(btn && typeof applyMute === 'function') applyMute(false);
            }
        }

        // Klik popup sendiri → unmute
        popup.addEventListener('click', function(e){
            e.stopPropagation();
            dismissPopup(true);
        });

        // Klik di mana saja → unmute
        document.addEventListener('click', function onAnyClick(){
            document.removeEventListener('click', onAnyClick);
            dismissPopup(true);
        }, {once:true});

        // Auto hide setelah 5 detik tanpa unmute
        var autoHide = setTimeout(function(){ dismissPopup(false); }, 5000);
        popup.addEventListener('click', function(){ clearTimeout(autoHide); });

        document.body.appendChild(popup);
    }

    function insertVideo(){
        function doInsert(){
            document.body.insertBefore(vid, document.body.firstChild);
            startVideo();
            // Popup muncul jika audio pernah di-unmute (localStorage) DAN:
            // - Di login page: selalu muncul (setiap refresh)
            // - Di router page: hanya muncul sekali per session (tidak muncul saat ganti menu)
            var isLoginPage = window.location.pathname.indexOf('login') !== -1;
            if(localStorage.getItem(MUTE_KEY) === 'false' &&
               (isLoginPage || !sessionStorage.getItem('ft_session_unmuted'))){
                setTimeout(showUnmutePopup, 600);
            }
        }
        if(document.body) doInsert();
        else document.addEventListener('DOMContentLoaded', doInsert);
    }
    insertVideo();

    // ── CONTROLS (proximity 80px, pojok kanan bawah) ───────
    var TRIGGER_RADIUS = 80;

    var cStyle = document.createElement('style');
    cStyle.textContent = [
        '#ft-controls{position:fixed;bottom:16px;right:16px;z-index:9999;display:flex;gap:8px;opacity:0;transform:translateY(6px);transition:opacity 0.25s ease,transform 0.25s ease;pointer-events:none;}',
        '#ft-controls.visible{opacity:1;transform:translateY(0);pointer-events:auto;}',
        '#ft-controls button{width:34px;height:34px;border-radius:50%;border:none;background:rgba(15,15,15,0.6);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);color:#fff;cursor:pointer;display:flex;align-items:center;justify-content:center;padding:0;transition:background 0.2s,transform 0.15s;box-shadow:0 2px 8px rgba(0,0,0,0.4);}',
        '#ft-controls button:hover{background:rgba(40,40,40,0.85);transform:scale(1.1);}',
        '#ft-controls button svg{width:16px;height:16px;fill:none;stroke:#fff;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;}',
        'body.ft-panel-hidden #container,body.ft-panel-hidden #navi,body.ft-panel-hidden #footer{opacity:0!important;pointer-events:none!important;transition:opacity 0.3s ease;}',
        'body:not(.ft-panel-hidden) #container,body:not(.ft-panel-hidden) #navi,body:not(.ft-panel-hidden) #footer{opacity:1;transition:opacity 0.3s ease;}'
    ].join('');
    document.head.appendChild(cStyle);

    var icons = {
        muted:  '<svg viewBox="0 0 24 24"><path d="M11 5L6 9H2v6h4l5 4V5z"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>',
        unmuted:'<svg viewBox="0 0 24 24"><path d="M11 5L6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>',
        hide:   '<svg viewBox="0 0 24 24"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
        show:   '<svg viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>'
    };

    var controls = document.createElement('div');
    controls.id = 'ft-controls';

    var btnPanel = document.createElement('button');
    function applyPanel(hidden){
        isPanelHidden = hidden;
        localStorage.setItem(PANEL_KEY, hidden ? 'true' : 'false');
        btnPanel.innerHTML = hidden ? icons.show : icons.hide;
        btnPanel.title     = hidden ? 'Show panels' : 'Hide panels';
        hidden ? document.body.classList.add('ft-panel-hidden')
               : document.body.classList.remove('ft-panel-hidden');
    }
    btnPanel.addEventListener('click', function(){ applyPanel(!isPanelHidden); });

    var btnMute = document.createElement('button');
    btnMute.id = 'ft-btn-mute';
    function applyMute(muted){
        isMuted   = muted;
        vid.muted = muted;
        localStorage.setItem(MUTE_KEY, muted ? 'true' : 'false');
        btnMute.innerHTML = muted ? icons.muted : icons.unmuted;
        btnMute.title     = muted ? 'Unmute' : 'Mute';
        if(muted){
            // Reset flag saat mute agar popup bisa muncul lagi jika unmute lagi
            sessionStorage.removeItem('ft_session_unmuted');
            var p = document.getElementById('ft-unmute-popup');
            if(p && p.parentNode){
                p.classList.add('ft-popup-out');
                setTimeout(function(){ if(p.parentNode) p.parentNode.removeChild(p); }, 300);
            }
        } else {
            // Set flag hanya di router page
            var isLoginPage = window.location.pathname.indexOf('login') !== -1;
            if(!isLoginPage) sessionStorage.setItem('ft_session_unmuted', '1');
        }
    }
    btnMute.addEventListener('click', function(){ applyMute(!isMuted); });

    controls.appendChild(btnPanel);
    controls.appendChild(btnMute);

    function attachControls(){
        document.body.appendChild(controls);
        applyMute(isMuted);
        applyPanel(isPanelHidden);
        document.addEventListener('mousemove', function(e){
            var rect = controls.getBoundingClientRect();
            var cx = rect.left + rect.width/2, cy = rect.top + rect.height/2;
            var dist = Math.sqrt(Math.pow(e.clientX-cx,2)+Math.pow(e.clientY-cy,2));
            dist < TRIGGER_RADIUS ? controls.classList.add('visible') : controls.classList.remove('visible');
        });
    }
    if(document.body) attachControls();
    else document.addEventListener('DOMContentLoaded', attachControls);

    // ── ONBOARDING TIP: HIDE PANEL (pertama kali login) ─────
    // Login.html set sessionStorage 'ft_show_panel_tip' saat first login
    if(sessionStorage.getItem('ft_show_panel_tip')){
        sessionStorage.removeItem('ft_show_panel_tip');
        setTimeout(function(){
            // Pastikan controls sudah ada di DOM
            var ctrl = document.getElementById('ft-controls');
            var bPanel = document.getElementById('ft-controls') &&
                         document.getElementById('ft-controls').querySelector('button:first-child');
            if(!ctrl) return;

            // Buat tooltip
            var tipStyle = document.createElement('style');
            tipStyle.textContent =
                '#ft-panel-tip{position:fixed;bottom:60px;right:16px;z-index:10000;' +
                'background:rgba(10,10,10,0.90);backdrop-filter:blur(12px);' +
                '-webkit-backdrop-filter:blur(12px);color:#fff;font-size:12px;' +
                'font-family:sans-serif;padding:10px 14px;border-radius:12px;' +
                'box-shadow:0 4px 20px rgba(0,0,0,0.5);max-width:200px;' +
                'line-height:1.6;pointer-events:auto;cursor:pointer;' +
                'animation:ftTipIn 0.3s ease;}' +
                '#ft-panel-tip::after{content:"";position:absolute;bottom:-4px;right:18px;' +
                'width:8px;height:8px;background:rgba(10,10,10,0.90);transform:rotate(45deg);}' +
                '@keyframes ftTipIn{from{opacity:0;transform:translateY(6px);}to{opacity:1;transform:translateY(0);}}' +
                '.ft-tip-pulse{animation:ftPulse 1.2s ease infinite!important;}' +
                '@keyframes ftPulse{0%,100%{box-shadow:0 2px 8px rgba(0,0,0,0.4);}' +
                '50%{box-shadow:0 0 0 4px rgba(255,255,255,0.25),0 2px 8px rgba(0,0,0,0.4);}}';
            document.head.appendChild(tipStyle);

            var tip = document.createElement('div');
            tip.id = 'ft-panel-tip';
            tip.innerHTML = '👁 <b>Tip:</b> Move cursor to the<br>bottom-right corner to show<br>controls. Click <b>hide</b> to toggle<br>the navigation panel.';
            document.body.appendChild(tip);

            // Highlight tombol panel
            ctrl.classList.add('visible');
            var bFirst = ctrl.querySelector('button:first-child');
            if(bFirst) bFirst.classList.add('ft-tip-pulse');

            function removeTip(){
                tip.style.transition = 'opacity 0.3s ease';
                tip.style.opacity = '0';
                setTimeout(function(){
                    tip.parentNode && tip.parentNode.removeChild(tip);
                    tipStyle.parentNode && tipStyle.parentNode.removeChild(tipStyle);
                }, 320);
                ctrl.classList.remove('visible');
                if(bFirst) bFirst.classList.remove('ft-tip-pulse');
            }
            tip.addEventListener('click', removeTip);
            setTimeout(removeTip, 8000);
        }, 1200);
    }

})();
