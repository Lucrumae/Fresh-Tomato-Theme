/* adaptiverealtime.js — FreshTomato True Realtime Adaptive Theme
   - requestAnimationFrame + throttle 100ms
   - Mengutamakan warna cerah & kontras (WCAG)
   - Volume control + hide panel toggle
*/
(function () {

    var style = document.createElement('style');
    style.textContent =
        '#bg-video{' +
            'position:fixed;top:0;left:0;' +
            'width:100vw;height:100vh;' +
            'z-index:-1;object-fit:cover;' +
            'object-position:center center;' +
            'pointer-events:none;' +
        '}' +
        '*{transition:background-color 0.8s ease,border-color 0.8s ease,color 0.8s ease!important;}' +
        'a,input,select,textarea,button{transition-duration:0.15s!important;}';
    document.head.appendChild(style);

    var vid = document.createElement('video');
    vid.id='bg-video'; vid.autoplay=vid.loop=vid.muted=vid.playsInline=true;
    vid.setAttribute('playsinline','');
    vid.crossOrigin='anonymous';
    var src=document.createElement('source');
    src.src='/bgmp4.gif'; src.type='video/mp4';
    vid.appendChild(src);
    function insertVideo(){
        if(document.body) document.body.insertBefore(vid,document.body.firstChild);
        else document.addEventListener('DOMContentLoaded',function(){ document.body.insertBefore(vid,document.body.firstChild); });
    }
    insertVideo();

    // --- UTILITY ---
    function rgbToHsl(r,g,b){
        r/=255;g/=255;b/=255;
        var max=Math.max(r,g,b),min=Math.min(r,g,b),h,s,l=(max+min)/2;
        if(max===min){h=s=0;}else{var d=max-min;s=l>0.5?d/(2-max-min):d/(max+min);switch(max){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;break;}}
        return[h*360,s*100,l*100];
    }
    function hslToRgb(h,s,l){
        h/=360;s/=100;l/=100;var r,g,b;
        if(s===0){r=g=b=l;}else{var q=l<0.5?l*(1+s):l+s-l*s,p=2*l-q;function hue2rgb(t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<0.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}r=hue2rgb(h+1/3);g=hue2rgb(h);b=hue2rgb(h-1/3);}
        return[Math.round(r*255),Math.round(g*255),Math.round(b*255)];
    }
    function relLum(r,g,b){function lin(c){c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);}return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b);}
    function cr(l1,l2){var a=Math.max(l1,l2),b=Math.min(l1,l2);return(a+0.05)/(b+0.05);}
    function bestText(r,g,b){return cr(1.0,relLum(r,g,b))>=cr(0.0,relLum(r,g,b))?[255,255,255]:[0,0,0];}
    function ensureContrast(fr,fg,fb,br,bg,bb,min){
        min=min||4.5;var bl=relLum(br,bg,bb);
        if(cr(relLum(fr,fg,fb),bl)>=min)return[fr,fg,fb];
        var hsl=rgbToHsl(fr,fg,fb),h=hsl[0],s=hsl[1],l=hsl[2],rgb;
        for(var li=l;li<=98;li+=2){rgb=hslToRgb(h,s,li);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}
        for(var ld=l;ld>=2;ld-=2){rgb=hslToRgb(h,s,ld);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}
        return bestText(br,bg,bb);
    }
    function rgb(c){return'rgb('+c[0]+','+c[1]+','+c[2]+')';}
    function rgba(c,a){return'rgba('+c[0]+','+c[1]+','+c[2]+','+a+')';}
    function set(k,v){document.documentElement.style.setProperty(k,v);}

    function applyPalette(r,g,b){
        var hsl=rgbToHsl(r,g,b),hue=hsl[0],sat=hsl[1],lum=hsl[2];
        var isDark=lum<50;
        var sat2=Math.max(sat,50);
        var pL=isDark?Math.min(lum+10,25):Math.max(lum-10,75);
        var hL=isDark?Math.min(lum+5,18):Math.max(lum-5,82);
        var panelRgb =hslToRgb(hue,Math.min(sat2,45),pL);
        var headerRgb=hslToRgb(hue,Math.min(sat2,50),hL);
        var accentRgb=hslToRgb(hue,Math.max(sat2,60),isDark?70:40);
        var accent2  =hslToRgb((hue+30)%360,Math.max(sat2,55),isDark?75:35);
        var accentHl =hslToRgb(hue,Math.max(sat2,50),isDark?88:25);
        var bgFb     =hslToRgb(hue,Math.min(sat,35),isDark?8:92);
        var eBgR=Math.round(panelRgb[0]*0.28+bgFb[0]*0.72);
        var eBgG=Math.round(panelRgb[1]*0.28+bgFb[1]*0.72);
        var eBgB=Math.round(panelRgb[2]*0.28+bgFb[2]*0.72);
        var tP  =ensureContrast(isDark?250:15,isDark?245:10,isDark?235:8,eBgR,eBgG,eBgB,5.0);
        var tS  =ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);
        var tV  =ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);
        var aSec=ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);
        var aHl =ensureContrast(accentHl[0],accentHl[1],accentHl[2],eBgR,eBgG,eBgB,3.5);
        var logB=isDark?[255,250,235]:[10,6,3];
        var logC=bestText(logB[0],logB[1],logB[2]);
        var inpB=hslToRgb(hue,Math.min(sat*0.25,12),isDark?94:10);
        var inpC=bestText(inpB[0],inpB[1],inpB[2]);
        var prog=hslToRgb((hue+15)%360,Math.max(sat2,65),isDark?72:38);
        var svgT=ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);

        set('--bg-fallback',     rgb(bgFb));
        set('--panel-bg',        rgba(panelRgb,0.28));
        set('--header-bg',       rgba(headerRgb,0.60));
        set('--log-bg',          rgb(logB));
        set('--bwm-bg',          rgba(panelRgb,0.07));
        set('--tab-bg',          rgba(headerRgb,0.35));
        set('--text-primary',    rgb(tP));
        set('--text-secondary',  rgb(tS));
        set('--text-value',      rgb(tV));
        set('--log-color',       rgb(logC));
        set('--tab-text',        rgb(tP));
        set('--accent-primary',  rgba(accentRgb,0.22));
        set('--accent-secondary',rgb(aSec));
        set('--accent-highlight',rgb(aHl));
        set('--link-color',      rgb(tS));
        set('--link-hover-color',rgb(aHl));
        set('--btn-bg',          rgba(accentRgb,0.22));
        set('--btn-color',       rgb(tP));
        set('--progress-color',  rgb(prog));
        set('--input-bg',        rgba(inpB,0.85));
        set('--input-color',     rgb(inpC));
        set('--input-border',    rgba(accentRgb,0.25));
        set('--svg-text-color',  rgb(svgT));
        set('--svg-grid-stroke', rgba(accentRgb,0.15));
        set('--bwm-border',      rgba(accentRgb,0.18));
        set('--svg-bg',          rgba(headerRgb,0.30));
        set('--tab-active-bg',   rgba(accentRgb,0.20));
        set('--row-even',        rgba(accentRgb,0.06));
        set('--row-odd',         rgba(accentRgb,0.02));
        set('--scrollbar-track', rgba(accentRgb,0.05));
        set('--scrollbar-thumb', rgba(accentRgb,0.40));
        set('--scrollbar-hover', rgba(accentRgb,0.65));
        document.documentElement.style.backgroundColor=rgb(bgFb);
    }

    // --- REALTIME LOOP ---
    var canvas=document.createElement('canvas');
    canvas.width=64;canvas.height=36;
    var ctx=canvas.getContext('2d');
    var lastHue=-1, lastSample=0, THROTTLE=100, HUE_THRESHOLD=5;

    function sample(){
        if(vid.readyState<2)return;
        try{
            ctx.drawImage(vid,0,0,64,36);
            var px=ctx.getImageData(0,0,64,36).data;
            var r=0,g=0,b=0,n=0;
            for(var i=0;i<px.length;i+=4){var pr=px[i],pg=px[i+1],pb=px[i+2],br=(pr+pg+pb)/3;if(br<15||br>240)continue;r+=pr;g+=pg;b+=pb;n++;}
            if(n===0)return;
            r=Math.round(r/n);g=Math.round(g/n);b=Math.round(b/n);
            var hsl=rgbToHsl(r,g,b),hue=hsl[0];
            if(lastHue>=0){var diff=Math.abs(hue-lastHue);if(diff>180)diff=360-diff;if(diff<HUE_THRESHOLD)return;}
            lastHue=hue;
            applyPalette(r,g,b);
        }catch(e){}
    }

    function loop(ts){
        if(ts-lastSample>=THROTTLE){lastSample=ts;sample();}
        requestAnimationFrame(loop);
    }

    vid.addEventListener('playing',function onPlay(){
        vid.removeEventListener('playing',onPlay);
        requestAnimationFrame(loop);
    });

    // ---------------------------------------------------------------
    // FLOATING CONTROLS: Volume + Hide Panel
    // ---------------------------------------------------------------
    function buildControls() {
        var ctrl = document.createElement('div');
        ctrl.id = 'ft-controls';

        var panelHidden = false;
        var muted = true;
        var vol = 0.5;

        var css = document.createElement('style');
        css.textContent = [
            '#ft-controls{',
                'position:fixed;bottom:18px;right:18px;',
                'z-index:9999;',
                'display:flex;flex-direction:column;gap:8px;',
                'align-items:flex-end;',
            '}',
            '#ft-controls button{',
                'width:38px;height:38px;',
                'border:none;border-radius:50%;',
                'cursor:pointer;font-size:16px;',
                'display:flex;align-items:center;justify-content:center;',
                'background:rgba(0,0,0,0.45);',
                'color:#fff;',
                'backdrop-filter:blur(6px);',
                '-webkit-backdrop-filter:blur(6px);',
                'box-shadow:0 2px 8px rgba(0,0,0,0.4);',
                'transition:background 0.2s,transform 0.15s;',
                'padding:0;line-height:1;',
            '}',
            '#ft-controls button:hover{',
                'background:rgba(0,0,0,0.7);',
                'transform:scale(1.1);',
            '}',
            '#ft-vol-slider{',
                'width:90px;height:4px;',
                'appearance:none;-webkit-appearance:none;',
                'background:rgba(255,255,255,0.3);',
                'border-radius:2px;outline:none;cursor:pointer;',
                'transition:opacity 0.2s;',
            '}',
            '#ft-vol-slider::-webkit-slider-thumb{',
                'appearance:none;-webkit-appearance:none;',
                'width:14px;height:14px;border-radius:50%;',
                'background:#fff;cursor:pointer;',
            '}',
            '#ft-vol-row{',
                'display:flex;align-items:center;gap:6px;',
                'background:rgba(0,0,0,0.45);',
                'backdrop-filter:blur(6px);',
                '-webkit-backdrop-filter:blur(6px);',
                'border-radius:20px;',
                'padding:0 10px 0 6px;',
                'height:38px;',
                'box-shadow:0 2px 8px rgba(0,0,0,0.4);',
                'overflow:hidden;',
                'max-width:38px;',
                'transition:max-width 0.35s ease,padding 0.35s ease;',
            '}',
            '#ft-vol-row.expanded{max-width:160px;padding:0 10px;}',
            '#ft-vol-row button{',
                'background:transparent!important;',
                'box-shadow:none!important;',
                'flex-shrink:0;',
            '}',
        ].join('');
        document.head.appendChild(css);

        /* Volume row */
        var volRow = document.createElement('div');
        volRow.id = 'ft-vol-row';

        var btnVol = document.createElement('button');
        btnVol.title = 'Toggle mute';
        btnVol.textContent = '🔇';

        var slider = document.createElement('input');
        slider.id = 'ft-vol-slider';
        slider.type = 'range';
        slider.min = 0; slider.max = 1; slider.step = 0.05;
        slider.value = vol;

        volRow.appendChild(btnVol);
        volRow.appendChild(slider);

        /* Hide panel button */
        var btnHide = document.createElement('button');
        btnHide.title = 'Toggle panels';
        btnHide.textContent = '👁';

        ctrl.appendChild(volRow);
        ctrl.appendChild(btnHide);

        /* --- EVENT HANDLERS --- */

        // Expand/collapse slider on hover
        volRow.addEventListener('mouseenter', function(){ volRow.classList.add('expanded'); });
        volRow.addEventListener('mouseleave', function(){ volRow.classList.remove('expanded'); });

        // Volume toggle mute
        btnVol.addEventListener('click', function(){
            muted = !muted;
            vid.muted = muted;
            if (!muted) vid.volume = vol;
            btnVol.textContent = muted ? '🔇' : (vol > 0.5 ? '🔊' : '🔉');
        });

        // Volume slider
        slider.addEventListener('input', function(){
            vol = parseFloat(slider.value);
            vid.volume = vol;
            if (vol === 0) {
                muted = true; vid.muted = true; btnVol.textContent = '🔇';
            } else {
                muted = false; vid.muted = false;
                btnVol.textContent = vol > 0.5 ? '🔊' : '🔉';
            }
        });

        // Hide/show panel
        var panelStyle = document.createElement('style');
        panelStyle.id = 'ft-hide-panel';
        document.head.appendChild(panelStyle);

        btnHide.addEventListener('click', function(){
            panelHidden = !panelHidden;
            panelStyle.textContent = panelHidden
                ? '#container,#navi,#content,.section,fieldset,#header{opacity:0!important;pointer-events:none!important;transition:opacity 0.4s!important;}'
                : '';
            btnHide.textContent = panelHidden ? '🙈' : '👁';
        });

        document.body.appendChild(ctrl);
    }

    if (document.body) buildControls();
    else document.addEventListener('DOMContentLoaded', buildControls);

})();
