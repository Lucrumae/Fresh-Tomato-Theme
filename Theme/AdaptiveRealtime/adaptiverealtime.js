/* adaptiverealtime.js — FreshTomato Adaptive Realtime Theme Engine
   - Inject video bgmp4.gif sebagai background fullscreen
   - Sample warna dominan setiap 5 detik secara realtime
   - Smooth transition saat warna berubah
   - Jaminan kontras WCAG pada semua teks
*/
(function () {

    // ---------------------------------------------------------------
    // INJECT CSS #bg-video + transition smooth untuk semua variable
    // ---------------------------------------------------------------
    var style = document.createElement('style');
    style.id = 'adaptiverealtime-base';
    style.textContent =
        '#bg-video{' +
            'position:fixed;top:0;left:0;' +
            'width:100vw;height:100vh;' +
            'z-index:-1;object-fit:cover;' +
            'object-position:center center;' +
            'pointer-events:none;' +
        '}' +
        /* Smooth transition semua elemen saat warna berubah */
        '*{transition:' +
            'background-color 1.2s ease,' +
            'border-color 1.2s ease,' +
            'color 1.2s ease' +
        '!important;}' +
        /* Kecualikan elemen yang tidak boleh ter-delay */
        'a,input,select,textarea,button{transition-duration:0.2s!important;}';
    document.head.appendChild(style);

    // ---------------------------------------------------------------
    // BUAT ELEMEN VIDEO
    // ---------------------------------------------------------------
    var vid = document.createElement('video');
    vid.id          = 'bg-video';
    vid.autoplay    = true;
    vid.loop        = true;
    vid.muted       = true;
    vid.playsInline = true;
    vid.setAttribute('playsinline', '');
    vid.crossOrigin = 'anonymous';

    var src = document.createElement('source');
    src.src  = '/bgmp4.gif';
    src.type = 'video/mp4';
    vid.appendChild(src);

    function insertVideo() {
        if (document.body) {
            document.body.insertBefore(vid, document.body.firstChild);
        } else {
            document.addEventListener('DOMContentLoaded', function () {
                document.body.insertBefore(vid, document.body.firstChild);
            });
        }
    }
    insertVideo();

    // ---------------------------------------------------------------
    // UTILITY: RGB <-> HSL, Luminance, Contrast
    // ---------------------------------------------------------------
    function rgbToHsl(r, g, b) {
        r /= 255; g /= 255; b /= 255;
        var max = Math.max(r,g,b), min = Math.min(r,g,b);
        var h, s, l = (max+min)/2;
        if (max === min) { h = s = 0; }
        else {
            var d = max - min;
            s = l > 0.5 ? d/(2-max-min) : d/(max+min);
            switch(max) {
                case r: h=((g-b)/d+(g<b?6:0))/6; break;
                case g: h=((b-r)/d+2)/6; break;
                case b: h=((r-g)/d+4)/6; break;
            }
        }
        return [h*360, s*100, l*100];
    }

    function hslToRgb(h, s, l) {
        h/=360; s/=100; l/=100;
        var r,g,b;
        if (s===0) { r=g=b=l; }
        else {
            var q = l<0.5 ? l*(1+s) : l+s-l*s;
            var p = 2*l-q;
            function hue2rgb(t) {
                if(t<0)t+=1; if(t>1)t-=1;
                if(t<1/6) return p+(q-p)*6*t;
                if(t<1/2) return q;
                if(t<2/3) return p+(q-p)*(2/3-t)*6;
                return p;
            }
            r=hue2rgb(h+1/3); g=hue2rgb(h); b=hue2rgb(h-1/3);
        }
        return [Math.round(r*255), Math.round(g*255), Math.round(b*255)];
    }

    function relativeLuminance(r,g,b) {
        function lin(c) { c/=255; return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4); }
        return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b);
    }

    function contrastRatio(l1,l2) {
        var lighter=Math.max(l1,l2), darker=Math.min(l1,l2);
        return (lighter+0.05)/(darker+0.05);
    }

    function bestTextColor(bgR,bgG,bgB) {
        var bgLum=relativeLuminance(bgR,bgG,bgB);
        return contrastRatio(1.0,bgLum) >= contrastRatio(0.0,bgLum)
            ? [255,255,255] : [0,0,0];
    }

    function ensureContrast(fgR,fgG,fgB, bgR,bgG,bgB, minRatio) {
        minRatio = minRatio||4.5;
        var bgLum=relativeLuminance(bgR,bgG,bgB);
        if (contrastRatio(relativeLuminance(fgR,fgG,fgB),bgLum)>=minRatio) return [fgR,fgG,fgB];
        var hsl=rgbToHsl(fgR,fgG,fgB), h=hsl[0], s=hsl[1], l=hsl[2];
        for (var li=l; li<=98; li+=2) {
            var rgb=hslToRgb(h,s,li);
            if (contrastRatio(relativeLuminance(rgb[0],rgb[1],rgb[2]),bgLum)>=minRatio) return rgb;
        }
        for (var ld=l; ld>=2; ld-=2) {
            var rgb2=hslToRgb(h,s,ld);
            if (contrastRatio(relativeLuminance(rgb2[0],rgb2[1],rgb2[2]),bgLum)>=minRatio) return rgb2;
        }
        return bestTextColor(bgR,bgG,bgB);
    }

    // ---------------------------------------------------------------
    // CORE: SAMPLE FRAME & GENERATE PALET
    // ---------------------------------------------------------------
    var canvas = document.createElement('canvas');
    canvas.width = 96; canvas.height = 54;
    var ctx = canvas.getContext('2d');

    // Track hue sebelumnya untuk deteksi perubahan signifikan
    var lastHue = -1;
    var HUE_THRESHOLD = 8; // derajat minimum sebelum update

    function sampleAndApply() {
        if (vid.readyState < 2) return; // video belum siap

        try {
            ctx.drawImage(vid, 0, 0, 96, 54);
            var pixels = ctx.getImageData(0, 0, 96, 54).data;

            var r=0, g=0, b=0, count=0;
            for (var i=0; i<pixels.length; i+=4) {
                var pr=pixels[i], pg=pixels[i+1], pb=pixels[i+2];
                var br=(pr+pg+pb)/3;
                if (br<15||br>240) continue;
                r+=pr; g+=pg; b+=pb; count++;
            }
            if (count===0) return;

            r=Math.round(r/count);
            g=Math.round(g/count);
            b=Math.round(b/count);

            var hsl=rgbToHsl(r,g,b);
            var hue=hsl[0], sat=hsl[1], lum=hsl[2];

            // Skip jika perubahan hue tidak signifikan (hemat CPU)
            if (lastHue >= 0) {
                var hueDiff = Math.abs(hue - lastHue);
                if (hueDiff > 180) hueDiff = 360 - hueDiff; // wrap around
                if (hueDiff < HUE_THRESHOLD) return;
            }
            lastHue = hue;

            var isDark = lum < 50;

            // Generate palet
            var panelL    = isDark ? Math.min(lum+8,22)  : Math.max(lum-8,78);
            var headerL   = isDark ? Math.min(lum+4,16)  : Math.max(lum-4,84);
            var panelRgb  = hslToRgb(hue, Math.min(sat,40), panelL);
            var headerRgb = hslToRgb(hue, Math.min(sat,45), headerL);
            var accentRgb = hslToRgb(hue, Math.max(sat,55), isDark?65:45);
            var accent2Rgb= hslToRgb((hue+30)%360, Math.max(sat,50), isDark?72:38);
            var accentHlRgb=hslToRgb(hue, Math.max(sat,45), isDark?82:30);
            var bgFallback= hslToRgb(hue, Math.min(sat,30), isDark?10:90);

            // Effective bg untuk kalkulasi kontras
            var eBgR=Math.round(panelRgb[0]*0.28+bgFallback[0]*0.72);
            var eBgG=Math.round(panelRgb[1]*0.28+bgFallback[1]*0.72);
            var eBgB=Math.round(panelRgb[2]*0.28+bgFallback[2]*0.72);

            var textPrimary    = ensureContrast(isDark?245:20, isDark?238:12, isDark?225:5, eBgR,eBgG,eBgB, 5.0);
            var textSecondary  = ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2], eBgR,eBgG,eBgB, 4.5);
            var textValue      = ensureContrast(accent2Rgb[0],accent2Rgb[1],accent2Rgb[2], eBgR,eBgG,eBgB, 4.5);
            var accentSec      = ensureContrast(accent2Rgb[0],accent2Rgb[1],accent2Rgb[2], eBgR,eBgG,eBgB, 4.5);
            var accentHl       = ensureContrast(accentHlRgb[0],accentHlRgb[1],accentHlRgb[2], eBgR,eBgG,eBgB, 3.5);
            var logBgRgb       = isDark?[255,248,230]:[15,8,5];
            var logColorRgb    = bestTextColor(logBgRgb[0],logBgRgb[1],logBgRgb[2]);
            var inputBgRgb     = hslToRgb(hue, Math.min(sat*0.3,15), isDark?92:12);
            var inputColor     = bestTextColor(inputBgRgb[0],inputBgRgb[1],inputBgRgb[2]);
            var progressRgb    = hslToRgb((hue+15)%360, Math.max(sat,60), isDark?68:42);
            var svgTextRgb     = ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2], eBgR,eBgG,eBgB, 4.5);

            function rgb(c)    { return 'rgb('+c[0]+','+c[1]+','+c[2]+')'; }
            function rgba(c,a) { return 'rgba('+c[0]+','+c[1]+','+c[2]+','+a+')'; }

            var R = document.documentElement;
            function set(k,v) { R.style.setProperty(k,v); }

            set('--bg-fallback',      rgb(bgFallback));
            set('--panel-bg',         rgba(panelRgb,0.28));
            set('--header-bg',        rgba(headerRgb,0.60));
            set('--log-bg',           rgb(logBgRgb));
            set('--bwm-bg',           rgba(panelRgb,0.07));
            set('--tab-bg',           rgba(headerRgb,0.35));

            set('--text-primary',     rgb(textPrimary));
            set('--text-secondary',   rgb(textSecondary));
            set('--text-value',       rgb(textValue));
            set('--log-color',        rgb(logColorRgb));
            set('--tab-text',         rgb(textPrimary));

            set('--accent-primary',   rgba(accentRgb,0.22));
            set('--accent-secondary', rgb(accentSec));
            set('--accent-highlight', rgb(accentHl));

            set('--link-color',       rgb(textSecondary));
            set('--link-hover-color', rgb(accentHl));

            set('--btn-bg',           rgba(accentRgb,0.22));
            set('--btn-color',        rgb(textPrimary));

            set('--progress-color',   rgb(progressRgb));

            set('--input-bg',         rgba(inputBgRgb,0.85));
            set('--input-color',      rgb(inputColor));
            set('--input-border',     rgba(accentRgb,0.25));

            set('--svg-text-color',   rgb(svgTextRgb));
            set('--svg-grid-stroke',  rgba(accentRgb,0.15));
            set('--bwm-border',       rgba(accentRgb,0.18));
            set('--svg-bg',           rgba(headerRgb,0.30));
            set('--tab-active-bg',    rgba(accentRgb,0.20));

            set('--row-even',         rgba(accentRgb,0.06));
            set('--row-odd',          rgba(accentRgb,0.02));

            set('--scrollbar-track',  rgba(accentRgb,0.05));
            set('--scrollbar-thumb',  rgba(accentRgb,0.40));
            set('--scrollbar-hover',  rgba(accentRgb,0.65));

            document.documentElement.style.backgroundColor = rgb(bgFallback);

        } catch(e) {
            // Canvas gagal — skip frame ini, coba lagi di interval berikutnya
        }
    }

    // ---------------------------------------------------------------
    // MULAI SAMPLING setelah video play, interval setiap 5 detik
    // ---------------------------------------------------------------
    vid.addEventListener('playing', function onPlay() {
        vid.removeEventListener('playing', onPlay);

        // Sample pertama langsung
        sampleAndApply();

        // Lalu setiap 5 detik
        setInterval(sampleAndApply, 5000);
    });

})();
