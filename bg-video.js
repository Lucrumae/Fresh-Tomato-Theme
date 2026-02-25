/* bg-video.js — FreshTomato Video Background Injector
   File video dinamai bgmp4.gif agar bisa diakses BusyBox httpd.
*/
(function () {
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
})();
