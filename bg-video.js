/* bg-video.js — FreshTomato Video Background Injector
   File video dinamai bgmp4.gif agar bisa diakses BusyBox httpd.
   State mute/unmute disimpan di localStorage agar persist antar halaman.
*/
(function () {
    var STORAGE_KEY = 'ft_bg_muted';

    var vid = document.createElement('video');
    vid.id = 'bg-video';
    vid.autoplay    = true;
    vid.loop        = true;
    vid.muted       = true;
    vid.playsInline = true;
    vid.setAttribute('playsinline', '');

    var src = document.createElement('source');
    src.src  = '/bgmp4.gif';
    src.type = 'video/mp4';
    vid.appendChild(src);

    document.body.insertBefore(vid, document.body.firstChild);

    // Baca state mute dari localStorage
    // Default: muted=true. Jika user sebelumnya unmute, langsung unmute.
    var savedMuted = localStorage.getItem(STORAGE_KEY);
    var isMuted = savedMuted === null ? true : savedMuted === 'true';

    function applyMute(muted) {
        isMuted = muted;
        vid.muted = muted;
        localStorage.setItem(STORAGE_KEY, muted ? 'true' : 'false');
        btn.innerHTML = muted ? '🔇' : '🔊';
        btn.title = muted ? 'Click to unmute' : 'Click to mute';
    }

    // Tombol mute/unmute
    var btn = document.createElement('button');
    btn.id = 'bg-mute-btn';
    btn.style.cssText = [
        'position:fixed',
        'bottom:16px',
        'right:16px',
        'z-index:9999',
        'background:rgba(0,0,0,0.45)',
        'color:#fff',
        'border:1px solid rgba(255,255,255,0.3)',
        'border-radius:50%',
        'width:36px',
        'height:36px',
        'font-size:16px',
        'cursor:pointer',
        'padding:0',
        'line-height:36px',
        'text-align:center',
        'transition:background 0.2s'
    ].join(';');

    btn.addEventListener('mouseover', function () { btn.style.background = 'rgba(0,0,0,0.7)'; });
    btn.addEventListener('mouseout',  function () { btn.style.background = 'rgba(0,0,0,0.45)'; });
    btn.addEventListener('click', function () { applyMute(!isMuted); });

    document.body.appendChild(btn);

    // Terapkan state setelah video siap
    // Perlu tunggu interaksi user untuk unmute pertama kali
    vid.addEventListener('canplay', function () {
        applyMute(isMuted);
    });

    // Inisialisasi tampilan tombol sesuai state tersimpan
    applyMute(isMuted);
})();
