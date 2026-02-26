/* adaptiverealtime.js — FreshTomato True Realtime Adaptive Theme
   - Sample warna setiap frame via requestAnimationFrame
   - Throttle: max 10 sample/detik (setiap 100ms)
   - HUE_THRESHOLD: skip update jika perubahan < 5 derajat
   - Smooth CSS transition 0.8s untuk pergantian warna halus
*/
(function () {

    // ---------------------------------------------------------------
    // INJECT CSS
    // ---------------------------------------------------------------
    var style = document.createElement('style');
    style.textContent =
        '#bg-video{' +
            'position:fixed;top:0;left:0;' +
            'width:100vw;height:100vh;' +
            'z-index:-1;object-fit:cover;' +
            'object-position:center center;' +
            'pointer-events:none;' +
        '}' +
        '*{transition:' +
            'background-color 0.8s ease,' +
            'border-color 0.8s ease,' +
            'color 0.8s ease' +
        '!important;}' +
        'a,input,select,textarea,button{transition-duration:0.15s!important;}';
    document.head.appendChild(style);

    // ---------------------------------------------------------------
    // VIDEO
    // ---------------------------------------------------------------
    var vid = document.createElement('video');
    vid.id='bg-video'; vid.autoplay=vid.loop=vid.muted=vid.playsInline=true;
    vid.setAttribute('playsinline','');
    vid.crossOrigin='anonymous';
    var s=document.createElement('source');
    s.src='/bgmp4.gif'; s.type='video/mp4';
    vid.appendChild(s);
    function insertVideo() {
        if (document.body) document.body.insertBefore(vid, document.body.firstChild);
        else document.addEventListener('DOMContentLoaded', function(){ document.body.insertBefore(vid, document.body.firstChild); });
    }
    insertVideo();

    // ---------------------------------------------------------------
    // UTILITY
    // ---------------------------------------------------------------
    function rgbToHsl(r,g,b) {
        r/=255;g/=255;b/=255;
        var max=Math.max(r,g,b),min=Math.min(r,g,b),h,s,l=(max+min)/2;
        if(max===min){h=s=0;}
        else{
            var d=max-min;
            s=l>0.5?d/(2-max-min):d/(max+min);
            switch(max){
                case r:h=((g-b)/d+(g<b?6:0))/6;break;
                case g:h=((b-r)/d+2)/6;break;
                case b:h=((r-g)/d+4)/6;break;
            }
        }
        return[h*360,s*100,l*100];
    }

    function hslToRgb(h,s,l) {
        h/=360;s/=100;l/=100;
        var r,g,b;
        if(s===0){r=g=b=l;}
        else{
            var q=l<0.5?l*(1+s):l+s-l*s,p=2*l-q;
            function hue2rgb(t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<0.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}
            r=hue2rgb(h+1/3);g=hue2rgb(h);b=hue2rgb(h-1/3);
        }
        return[Math.round(r*255),Math.round(g*255),Math.round(b*255)];
    }

    function relLum(r,g,b){
        function lin(c){c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);}
        return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b);
    }

    function cr(l1,l2){var a=Math.max(l1,l2),b=Math.min(l1,l2);return(a+0.05)/(b+0.05);}

    function bestText(br,bg,bb){
        return cr(1.0,relLum(br,bg,bb))>=cr(0.0,relLum(br,bg,bb))?[255,255,255]:[0,0,0];
    }

    function ensureContrast(fr,fg,fb,br,bg,bb,min){
        min=min||4.5;
        var bl=relLum(br,bg,bb);
        if(cr(relLum(fr,fg,fb),bl)>=min)return[fr,fg,fb];
        var hsl=rgbToHsl(fr,fg,fb),h=hsl[0],s=hsl[1],l=hsl[2],rgb;
        for(var li=l;li<=98;li+=2){rgb=hslToRgb(h,s,li);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}
        for(var ld=l;ld>=2;ld-=2){rgb=hslToRgb(h,s,ld);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}
        return bestText(br,bg,bb);
    }

    function rgb(c){return 'rgb('+c[0]+','+c[1]+','+c[2]+')';}
    function rgba(c,a){return 'rgba('+c[0]+','+c[1]+','+c[2]+','+a+')';}
    function set(k,v){document.documentElement.style.setProperty(k,v);}

    // ---------------------------------------------------------------
    // SAMPLING ENGINE
    // ---------------------------------------------------------------
    var canvas=document.createElement('canvas');
    canvas.width=64; canvas.height=36; // kecil = cepat
    var ctx=canvas.getContext('2d');

    var lastHue=-1;
    var lastSample=0;
    var THROTTLE=100;    // ms minimum antar sample
    var HUE_THRESHOLD=5; // derajat minimum sebelum update CSS

    function sample() {
        if(vid.readyState<2) return;

        try {
            ctx.drawImage(vid,0,0,64,36);
            var px=ctx.getImageData(0,0,64,36).data;
            var r=0,g=0,b=0,n=0;
            for(var i=0;i<px.length;i+=4){
                var pr=px[i],pg=px[i+1],pb=px[i+2],br=(pr+pg+pb)/3;
                if(br<15||br>240)continue;
                r+=pr;g+=pg;b+=pb;n++;
            }
            if(n===0)return;
            r=Math.round(r/n);g=Math.round(g/n);b=Math.round(b/n);

            var hsl=rgbToHsl(r,g,b);
            var hue=hsl[0],sat=hsl[1],lum=hsl[2];

            // Throttle hue check
            if(lastHue>=0){
                var diff=Math.abs(hue-lastHue);
                if(diff>180)diff=360-diff;
                if(diff<HUE_THRESHOLD)return;
            }
            lastHue=hue;

            var isDark=lum<50;
            var pL=isDark?Math.min(lum+8,22):Math.max(lum-8,78);
            var hL=isDark?Math.min(lum+4,16):Math.max(lum-4,84);
            var panelRgb  =hslToRgb(hue,Math.min(sat,40),pL);
            var headerRgb =hslToRgb(hue,Math.min(sat,45),hL);
            var accentRgb =hslToRgb(hue,Math.max(sat,55),isDark?65:45);
            var accent2   =hslToRgb((hue+30)%360,Math.max(sat,50),isDark?72:38);
            var accentHl  =hslToRgb(hue,Math.max(sat,45),isDark?82:30);
            var bgFb      =hslToRgb(hue,Math.min(sat,30),isDark?10:90);
            var eBgR=Math.round(panelRgb[0]*0.28+bgFb[0]*0.72);
            var eBgG=Math.round(panelRgb[1]*0.28+bgFb[1]*0.72);
            var eBgB=Math.round(panelRgb[2]*0.28+bgFb[2]*0.72);

            var tP  =ensureContrast(isDark?245:20,isDark?238:12,isDark?225:5,eBgR,eBgG,eBgB,5.0);
            var tS  =ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);
            var tV  =ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);
            var aSec=ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);
            var aHl =ensureContrast(accentHl[0],accentHl[1],accentHl[2],eBgR,eBgG,eBgB,3.5);
            var logB=isDark?[255,248,230]:[15,8,5];
            var logC=bestText(logB[0],logB[1],logB[2]);
            var inpB=hslToRgb(hue,Math.min(sat*0.3,15),isDark?92:12);
            var inpC=bestText(inpB[0],inpB[1],inpB[2]);
            var prog=hslToRgb((hue+15)%360,Math.max(sat,60),isDark?68:42);
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

        } catch(e) {}
    }

    // ---------------------------------------------------------------
    // LOOP via requestAnimationFrame + throttle 100ms
    // ---------------------------------------------------------------
    function loop(ts) {
        if(ts - lastSample >= THROTTLE) {
            lastSample = ts;
            sample();
        }
        requestAnimationFrame(loop);
    }

    vid.addEventListener('playing', function onPlay() {
        vid.removeEventListener('playing', onPlay);
        requestAnimationFrame(loop);
    });

})();
