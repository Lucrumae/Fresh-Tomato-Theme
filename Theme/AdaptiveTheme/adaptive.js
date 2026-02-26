/* adaptive.js — FreshTomato Adaptive Video Background
   - Inject video bgmp4.gif sebagai background fullscreen
   - Sample warna dominan sekali saat video play
   - Update CSS variables otomatis sesuai warna background
*/
(function () {

    // ---------------------------------------------------------------
    // 1. INJECT CSS #bg-video langsung via JS agar pasti ter-apply
    //    sebelum video element dibuat
    // ---------------------------------------------------------------
    var style = document.createElement('style');
    style.textContent = [
        '#bg-video {',
        '  position: fixed;',
        '  top: 0; left: 0;',
        '  width: 100vw; height: 100vh;',
        '  z-index: -1;',
        '  object-fit: cover;',
        '  object-position: center center;',
        '  pointer-events: none;',
        '}'
    ].join('\n');
    document.head.appendChild(style);

    // ---------------------------------------------------------------
    // 2. BUAT ELEMEN VIDEO
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

    // Pastikan body sudah ada sebelum insert
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
    // 3. COLOR SAMPLING — sekali saat video mulai play
    // ---------------------------------------------------------------
    vid.addEventListener('playing', function onPlay() {
        vid.removeEventListener('playing', onPlay);

        try {
            var canvas = document.createElement('canvas');
            canvas.width  = 64;
            canvas.height = 36;
            var ctx = canvas.getContext('2d');
            ctx.drawImage(vid, 0, 0, 64, 36);

            var pixels = ctx.getImageData(0, 0, 64, 36).data;

            var r = 0, g = 0, b = 0, count = 0;
            for (var i = 0; i < pixels.length; i += 4) {
                var pr = pixels[i], pg = pixels[i+1], pb = pixels[i+2];
                var br = (pr + pg + pb) / 3;
                if (br < 20 || br > 235) continue;
                r += pr; g += pg; b += pb; count++;
            }

            if (count === 0) return;

            r = Math.round(r / count);
            g = Math.round(g / count);
            b = Math.round(b / count);

            var luminance = (0.299 * r + 0.587 * g + 0.114 * b);
            var isDark = luminance < 128;

            var panelBg, panelEdge, headerBg, textPrimary, textSecondary;

            if (isDark) {
                panelBg       = 'rgba(' + Math.min(r+10,255) + ',' + Math.min(g+10,255) + ',' + Math.min(b+10,255) + ',0.45)';
                panelEdge     = 'rgba(' + Math.min(r+40,255) + ',' + Math.min(g+40,255) + ',' + Math.min(b+40,255) + ',0.6)';
                headerBg      = 'rgba(' + Math.max(r-10,0)   + ',' + Math.max(g-10,0)   + ',' + Math.max(b-10,0)   + ',0.75)';
                textPrimary   = '#f0ece8';
                textSecondary = 'rgba(240,236,232,0.65)';
            } else {
                panelBg       = 'rgba(' + Math.min(r+30,255) + ',' + Math.min(g+30,255) + ',' + Math.min(b+30,255) + ',0.35)';
                panelEdge     = 'rgba(' + Math.max(r-30,0)   + ',' + Math.max(g-30,0)   + ',' + Math.max(b-30,0)   + ',0.55)';
                headerBg      = 'rgba(' + Math.max(r-20,0)   + ',' + Math.max(g-20,0)   + ',' + Math.max(b-20,0)   + ',0.78)';
                textPrimary   = '#1a0a00';
                textSecondary = 'rgba(30,15,0,0.65)';
            }

            var accent = 'rgb(' + r + ',' + g + ',' + b + ')';
            var accentContrast = isDark
                ? 'rgb(' + Math.min(r+80,255) + ',' + Math.min(g+80,255) + ',' + Math.min(b+80,255) + ')'
                : 'rgb(' + Math.max(r-80,0)   + ',' + Math.max(g-80,0)   + ',' + Math.max(b-80,0)   + ')';

            var root = document.documentElement;
            root.style.setProperty('--panel-bg',        panelBg);
            root.style.setProperty('--panel-edge',      panelEdge);
            root.style.setProperty('--header-bg',       headerBg);
            root.style.setProperty('--text-primary',    textPrimary);
            root.style.setProperty('--text-secondary',  textSecondary);
            root.style.setProperty('--accent-auto',     accent);
            root.style.setProperty('--accent-contrast', accentContrast);

        } catch (e) {
            // Canvas CORS gagal — tema tetap pakai CSS default
        }
    });

})();
