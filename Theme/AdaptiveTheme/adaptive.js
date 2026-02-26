/* adaptive.js — FreshTomato Adaptive Theme Engine
   - Inject video bgmp4.gif sebagai background fullscreen
   - Sample warna dominan dari frame pertama video
   - Generate seluruh palet warna otomatis dengan jaminan kontras terbaca
*/
(function () {

    // ---------------------------------------------------------------
    // INJECT CSS #bg-video via JS agar pasti applied
    // ---------------------------------------------------------------
    var style = document.createElement('style');
    style.id = 'adaptive-base';
    style.textContent =
        '#bg-video{' +
            'position:fixed;top:0;left:0;' +
            'width:100vw;height:100vh;' +
            'z-index:-1;object-fit:cover;' +
            'object-position:center center;' +
            'pointer-events:none;' +
        '}';
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
    // UTILITY: Konversi RGB ke HSL
    // ---------------------------------------------------------------
    function rgbToHsl(r, g, b) {
        r /= 255; g /= 255; b /= 255;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h, s, l = (max + min) / 2;
        if (max === min) {
            h = s = 0;
        } else {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
                case r: h = ((g - b) / d + (g < b ? 6 : 0)) / 6; break;
                case g: h = ((b - r) / d + 2) / 6; break;
                case b: h = ((r - g) / d + 4) / 6; break;
            }
        }
        return [h * 360, s * 100, l * 100];
    }

    // HSL ke RGB string
    function hslToRgb(h, s, l) {
        h /= 360; s /= 100; l /= 100;
        var r, g, b;
        if (s === 0) {
            r = g = b = l;
        } else {
            var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
            var p = 2 * l - q;
            function hue2rgb(t) {
                if (t < 0) t += 1;
                if (t > 1) t -= 1;
                if (t < 1/6) return p + (q - p) * 6 * t;
                if (t < 1/2) return q;
                if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
                return p;
            }
            r = hue2rgb(h + 1/3);
            g = hue2rgb(h);
            b = hue2rgb(h - 1/3);
        }
        return [Math.round(r*255), Math.round(g*255), Math.round(b*255)];
    }

    // Luminance relatif (WCAG)
    function relativeLuminance(r, g, b) {
        var rs = r/255, gs = g/255, bs = b/255;
        function lin(c) { return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4); }
        return 0.2126*lin(rs) + 0.7152*lin(gs) + 0.0722*lin(bs);
    }

    // Rasio kontras WCAG (min 4.5 untuk teks normal)
    function contrastRatio(l1, l2) {
        var lighter = Math.max(l1, l2);
        var darker  = Math.min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
    }

    // Cari warna teks (hitam/putih) yang paling kontras terhadap bg
    function bestTextColor(bgR, bgG, bgB) {
        var bgLum   = relativeLuminance(bgR, bgG, bgB);
        var whiteLum = 1.0;
        var blackLum = 0.0;
        var whiteContrast = contrastRatio(whiteLum, bgLum);
        var blackContrast = contrastRatio(blackLum, bgLum);
        return whiteContrast >= blackContrast ? [255, 255, 255] : [0, 0, 0];
    }

    // Pastikan warna teks cukup kontras, adjust lightness jika perlu
    function ensureContrast(fgR, fgG, fgB, bgR, bgG, bgB, minRatio) {
        minRatio = minRatio || 4.5;
        var bgLum = relativeLuminance(bgR, bgG, bgB);
        var fgLum = relativeLuminance(fgR, fgG, fgB);

        if (contrastRatio(fgLum, bgLum) >= minRatio) {
            return [fgR, fgG, fgB]; // sudah cukup kontras
        }

        // Tentukan arah penyesuaian: terangkan atau gelapkan
        var hsl = rgbToHsl(fgR, fgG, fgB);
        var h = hsl[0], s = hsl[1], l = hsl[2];

        // Coba terangkan dulu
        for (var li = l; li <= 98; li += 2) {
            var rgb = hslToRgb(h, s, li);
            if (contrastRatio(relativeLuminance(rgb[0],rgb[1],rgb[2]), bgLum) >= minRatio) {
                return rgb;
            }
        }
        // Coba gelapkan
        for (var ld = l; ld >= 2; ld -= 2) {
            var rgb2 = hslToRgb(h, s, ld);
            if (contrastRatio(relativeLuminance(rgb2[0],rgb2[1],rgb2[2]), bgLum) >= minRatio) {
                return rgb2;
            }
        }
        // Fallback ke hitam/putih
        return bestTextColor(bgR, bgG, bgB);
    }

    // ---------------------------------------------------------------
    // COLOR SAMPLING — sekali saat video play
    // ---------------------------------------------------------------
    vid.addEventListener('playing', function onPlay() {
        vid.removeEventListener('playing', onPlay);

        try {
            // Sample dari 9 zona berbeda (3x3 grid) untuk hasil lebih akurat
            var cw = 96, ch = 54;
            var canvas = document.createElement('canvas');
            canvas.width = cw; canvas.height = ch;
            var ctx = canvas.getContext('2d');
            ctx.drawImage(vid, 0, 0, cw, ch);
            var pixels = ctx.getImageData(0, 0, cw, ch).data;

            var r = 0, g = 0, b = 0, count = 0;
            for (var i = 0; i < pixels.length; i += 4) {
                var pr = pixels[i], pg = pixels[i+1], pb = pixels[i+2];
                var br = (pr + pg + pb) / 3;
                if (br < 15 || br > 240) continue; // skip terlalu gelap/terang
                r += pr; g += pg; b += pb; count++;
            }
            if (count === 0) return;

            // Warna rata-rata dominan dari video
            var dr = Math.round(r / count);
            var dg = Math.round(g / count);
            var db = Math.round(b / count);

            var hsl     = rgbToHsl(dr, dg, db);
            var hue     = hsl[0];
            var sat     = hsl[1];
            var lum     = hsl[2];
            var isDark  = lum < 50;

            // ---------------------------------------------------------
            // GENERATE PALET dari hue yang ditemukan
            // ---------------------------------------------------------

            // Panel: hue yang sama tapi sangat gelap & transparan
            var panelL   = isDark ? Math.min(lum + 8, 22)  : Math.max(lum - 8, 78);
            var panelRgb = hslToRgb(hue, Math.min(sat, 40), panelL);
            var panelBg  = 'rgba('+panelRgb[0]+','+panelRgb[1]+','+panelRgb[2]+',0.28)';

            // Header: lebih pekat dari panel
            var headerL   = isDark ? Math.min(lum + 4, 16) : Math.max(lum - 4, 84);
            var headerRgb = hslToRgb(hue, Math.min(sat, 45), headerL);
            var headerBg  = 'rgba('+headerRgb[0]+','+headerRgb[1]+','+headerRgb[2]+',0.60)';

            // Accent primary: warna hidup dari hue video
            var accentRgb = hslToRgb(hue, Math.max(sat, 55), isDark ? 65 : 45);
            // Accent secondary: hue +30 (analogous)
            var accent2Rgb = hslToRgb((hue + 30) % 360, Math.max(sat, 50), isDark ? 72 : 38);
            // Accent highlight: lebih terang/muda
            var accentHlRgb = hslToRgb(hue, Math.max(sat, 45), isDark ? 82 : 30);

            // Panel background yang "dirasakan" (untuk keperluan kontras teks)
            // Campurkan panel rgba dengan bg fallback
            var bgFallbackRgb = hslToRgb(hue, Math.min(sat, 30), isDark ? 10 : 90);
            var effectiveBgR = Math.round(panelRgb[0] * 0.28 + bgFallbackRgb[0] * 0.72);
            var effectiveBgG = Math.round(panelRgb[1] * 0.28 + bgFallbackRgb[1] * 0.72);
            var effectiveBgB = Math.round(panelRgb[2] * 0.28 + bgFallbackRgb[2] * 0.72);

            // Text colors — dijamin kontras minimum 4.5:1 terhadap effective bg
            var textPrimaryRaw   = isDark ? [245, 238, 225] : [20, 12, 5];
            var textPrimary      = ensureContrast(
                textPrimaryRaw[0], textPrimaryRaw[1], textPrimaryRaw[2],
                effectiveBgR, effectiveBgG, effectiveBgB, 5.0
            );

            var textSecondaryRaw = accentRgb;
            var textSecondary    = ensureContrast(
                textSecondaryRaw[0], textSecondaryRaw[1], textSecondaryRaw[2],
                effectiveBgR, effectiveBgG, effectiveBgB, 4.5
            );

            var textValueRaw  = accent2Rgb;
            var textValue     = ensureContrast(
                textValueRaw[0], textValueRaw[1], textValueRaw[2],
                effectiveBgR, effectiveBgG, effectiveBgB, 4.5
            );

            var accentSecondary = ensureContrast(
                accent2Rgb[0], accent2Rgb[1], accent2Rgb[2],
                effectiveBgR, effectiveBgG, effectiveBgB, 4.5
            );

            var accentHighlight = ensureContrast(
                accentHlRgb[0], accentHlRgb[1], accentHlRgb[2],
                effectiveBgR, effectiveBgG, effectiveBgB, 3.5
            );

            // Log background: harus SANGAT kontras karena opaque
            var logBgRgb    = isDark ? [255, 248, 230] : [15, 8, 5];
            var logColorRgb = bestTextColor(logBgRgb[0], logBgRgb[1], logBgRgb[2]);

            // Input background
            var inputBgRgb = hslToRgb(hue, Math.min(sat * 0.3, 15), isDark ? 92 : 12);
            var inputColor = bestTextColor(inputBgRgb[0], inputBgRgb[1], inputBgRgb[2]);

            // Border accent
            var borderAlpha = 0.22;
            var accentBorder = 'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+','+borderAlpha+')';

            // Progress bar
            var progressRgb = hslToRgb((hue + 15) % 360, Math.max(sat, 60), isDark ? 68 : 42);

            // Row alternating
            var rowEven = 'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.06)';
            var rowOdd  = 'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.02)';

            // SVG
            var svgTextRgb = ensureContrast(
                accentRgb[0], accentRgb[1], accentRgb[2],
                effectiveBgR, effectiveBgG, effectiveBgB, 4.5
            );

            // Scrollbar
            var scrollThumb = 'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.40)';
            var scrollHover = 'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.65)';

            // ---------------------------------------------------------
            // SET semua CSS variables sekaligus
            // ---------------------------------------------------------
            var R = document.documentElement;
            function set(k, v) { R.style.setProperty(k, v); }

            set('--bg-fallback',       'rgb('+bgFallbackRgb[0]+','+bgFallbackRgb[1]+','+bgFallbackRgb[2]+')');
            set('--panel-bg',          panelBg);
            set('--header-bg',         headerBg);
            set('--log-bg',            'rgb('+logBgRgb[0]+','+logBgRgb[1]+','+logBgRgb[2]+')');
            set('--bwm-bg',            'rgba('+panelRgb[0]+','+panelRgb[1]+','+panelRgb[2]+',0.07)');
            set('--tab-bg',            'rgba('+headerRgb[0]+','+headerRgb[1]+','+headerRgb[2]+',0.35)');

            set('--text-primary',      'rgb('+textPrimary[0]+','+textPrimary[1]+','+textPrimary[2]+')');
            set('--text-secondary',    'rgb('+textSecondary[0]+','+textSecondary[1]+','+textSecondary[2]+')');
            set('--text-value',        'rgb('+textValue[0]+','+textValue[1]+','+textValue[2]+')');
            set('--log-color',         'rgb('+logColorRgb[0]+','+logColorRgb[1]+','+logColorRgb[2]+')');
            set('--tab-text',          'rgb('+textPrimary[0]+','+textPrimary[1]+','+textPrimary[2]+')');

            set('--accent-primary',    accentBorder);
            set('--accent-secondary',  'rgb('+accentSecondary[0]+','+accentSecondary[1]+','+accentSecondary[2]+')');
            set('--accent-highlight',  'rgb('+accentHighlight[0]+','+accentHighlight[1]+','+accentHighlight[2]+')');

            set('--link-color',        'rgb('+textSecondary[0]+','+textSecondary[1]+','+textSecondary[2]+')');
            set('--link-hover-color',  'rgb('+accentHighlight[0]+','+accentHighlight[1]+','+accentHighlight[2]+')');

            set('--btn-bg',            'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.22)');
            set('--btn-color',         'rgb('+textPrimary[0]+','+textPrimary[1]+','+textPrimary[2]+')');

            set('--progress-color',    'rgb('+progressRgb[0]+','+progressRgb[1]+','+progressRgb[2]+')');

            set('--input-bg',          'rgba('+inputBgRgb[0]+','+inputBgRgb[1]+','+inputBgRgb[2]+',0.85)');
            set('--input-color',       'rgb('+inputColor[0]+','+inputColor[1]+','+inputColor[2]+')');
            set('--input-border',      accentBorder);

            set('--svg-text-color',    'rgb('+svgTextRgb[0]+','+svgTextRgb[1]+','+svgTextRgb[2]+')');
            set('--svg-grid-stroke',   'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.15)');
            set('--bwm-border',        'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.18)');
            set('--svg-bg',            'rgba('+headerRgb[0]+','+headerRgb[1]+','+headerRgb[2]+',0.30)');
            set('--tab-active-bg',     'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.20)');

            set('--row-even',          rowEven);
            set('--row-odd',           rowOdd);

            set('--scrollbar-track',   'rgba('+accentRgb[0]+','+accentRgb[1]+','+accentRgb[2]+',0.05)');
            set('--scrollbar-thumb',   scrollThumb);
            set('--scrollbar-hover',   scrollHover);

            // Update fallback bg di html juga
            document.documentElement.style.backgroundColor =
                'rgb('+bgFallbackRgb[0]+','+bgFallbackRgb[1]+','+bgFallbackRgb[2]+')';

        } catch(e) {
            // Canvas CORS gagal — CSS fallback dari default.css tetap aktif
        }
    });

})();
