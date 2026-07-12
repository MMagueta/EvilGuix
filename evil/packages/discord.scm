(define-module (evil packages discord)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg))

(define %discord-version "1.0.146")
(define %discord-base-url
  (string-append "https://stable.dl2.discordapp.net/distro/app/stable/linux/x64/"
                 %discord-version "/"))

(define (discord-origin file hash)
  (origin
    (method url-fetch)
    (uri (string-append %discord-base-url file))
    (sha256 (base32 hash))))

(define %discord-modules
  `(("discord_cloudsync" ,(discord-origin "discord_cloudsync/1/full.distro"
                                            "03r55n8jbwyp7r7d29r9dah9fq604q6a2ar64byq1nkgswf49d6f"))
    ("discord_desktop_core" ,(discord-origin "discord_desktop_core/1/full.distro"
                                                "0klclvd750flb67y3z1ij743zhickvjp4gpp5kd7mm413x1ylgwg"))
    ("discord_dispatch" ,(discord-origin "discord_dispatch/1/full.distro"
                                           "0la95kwspfwkfsqdsqdnvknn5b6hn7flj93vs1yscnn1vkzryd4f"))
    ("discord_erlpack" ,(discord-origin "discord_erlpack/1/full.distro"
                                          "04wklzlnlzj1zlphcscwyjclcfx4bs0l8sz6cxav68zij7a5haw1"))
    ("discord_game_utils" ,(discord-origin "discord_game_utils/1/full.distro"
                                             "0xc3m228y1c29hzr5yrw9lv5sgkmvfb17l5w7v35jg1w3q018hzd"))
    ("discord_krisp" ,(discord-origin "discord_krisp/1/full.distro"
                                        "0p5hwi256739z67l5jpq5la6m2ns0kd60y9kxqfkb3g89ancij8f"))
    ("discord_modules" ,(discord-origin "discord_modules/1/full.distro"
                                          "0fw8lc8qmdn1dbkqqp59x74c4323gaf4ayjams2qs3rdg9x23b6x"))
    ("discord_rpc" ,(discord-origin "discord_rpc/1/full.distro"
                                      "00cf03ckv24206a9hpwxysnnl7w4a1gxr7pr5qd686y77gryhgrr"))
    ("discord_spellcheck" ,(discord-origin "discord_spellcheck/1/full.distro"
                                             "07kn66nzlw04qr8i8qw8rshh9sl9877xcym4wmifc1f9r666lr0r"))
    ("discord_utils" ,(discord-origin "discord_utils/1/full.distro"
                                        "0dzpfq0ll1x6g0s1a5l4hn80cdhw33kq5isdvgp6rb0wkjmfv5q0"))
    ("discord_voice" ,(discord-origin "discord_voice/1/full.distro"
                                        "1mzigkjx5fpr4d6ilxxp5qj9ly4fr5sfnrwx3w51d6vsfikd08an"))
    ("discord_zstd" ,(discord-origin "discord_zstd/1/full.distro"
                                       "03h6jdnddzashx4scl486789jd9g14pk5fnvmkypj7dl9vnpd40y"))))

(define-public discord
  (package
    (name "discord")
    (version %discord-version)
    (source
     (discord-origin "full.distro"
                     "1nj8ag23bsa2rfn50d233qn46lx0v9shgph7has423lclv839rqc"))
    (build-system gnu-build-system)
    (supported-systems '("x86_64-linux"))
    (arguments
     (list
      #:tests? #f
      #:strip-binaries? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'unpack)
          (delete 'configure)
          (delete 'build)
          (replace 'install
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (use-modules (guix build utils)
                           (srfi srfi-1))
              (let* ((out (assoc-ref outputs "out"))
                     (opt (string-append out "/opt/Discord"))
                     (modules (string-append opt "/modules"))
                     (unpack-distro
                      (lambda (source destination)
                        (mkdir-p destination)
                        (invoke "sh" "-c"
                                (string-append "brotli -d < " source
                                               " | tar -xf - --strip-components=1 -C "
                                               destination)))))
                (unpack-distro (assoc-ref inputs "source") opt)
                (for-each
                 (lambda (module)
                   (let ((destination (string-append modules "/" module)))
                     (unpack-distro (assoc-ref inputs module) destination)))
                 '#$(map car %discord-modules))
                (mkdir-p (string-append out "/bin"))
                (mkdir-p (string-append out "/share/applications"))
                (mkdir-p (string-append out "/share/icons/hicolor/256x256/apps"))
                (symlink (string-append opt "/Discord")
                         (string-append out "/bin/discord"))
                (symlink (string-append opt "/discord.png")
                         (string-append out "/share/icons/hicolor/256x256/apps/discord.png"))
                (call-with-output-file
                    (string-append out "/share/applications/discord.desktop")
                  (lambda (port)
                    (display "[Desktop Entry]\nName=Discord\nGenericName=Internet Messenger\nExec=discord\nIcon=discord\nType=Application\nCategories=Network;InstantMessaging;\nMimeType=x-scheme-handler/discord;\n" port)))
                (substitute* (string-append opt "/resources/build_info.json")
                  (((string-append "\"version\": \"" #$version "\""))
                   (string-append "\"version\": \"" #$version
                                  "\", \"SKIP_HOST_UPDATE\": true"
                                  ", \"localModulesRoot\": \"" modules "\""))))))
          (add-after 'install 'patch-elf
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (use-modules (guix build utils)
                           (srfi srfi-1))
              (let* ((out (assoc-ref outputs "out"))
                     (discord (string-append out "/opt/Discord/Discord"))
                     (rpath (string-join
                             (cons (string-append out "/opt/Discord")
                                   (filter file-exists?
                                           (append-map
                                            (lambda (input)
                                              (list (string-append (cdr input) "/lib")
                                                    (string-append (cdr input) "/lib/nss")))
                                            inputs)))
                             ":")))
                (for-each (lambda (file)
                            (when (elf-file? file)
                              (invoke "patchelf" "--set-rpath"
                                      (string-append "$ORIGIN:" rpath) file)
                              (when (zero? (system* "patchelf" "--print-interpreter" file))
                                (invoke "patchelf" "--set-interpreter"
                                        (search-input-file inputs "/lib/ld-linux-x86-64.so.2")
                                        file))))
                          (find-files (string-append out "/opt/Discord")))
                (wrap-program discord
                  `("LD_LIBRARY_PATH" prefix (,rpath))
                  `("DISCORD_DISABLE_HOST_UPDATE" = ("true")))))))))
    (native-inputs
     (append `(("brotli" ,brotli)
               ("patchelf" ,patchelf)
               ("tar" ,tar))
             %discord-modules))
    (inputs
     (list alsa-lib
           at-spi2-core
           cairo
           cups
           dbus
           eudev
           expat
           fontconfig
           freetype
           (list gcc "lib")
           gdk-pixbuf
           glib
           glibc
           gtk+
           libappindicator
           libdrm
           libglvnd
           libnotify
           libx11
           libxcb
           libxcomposite
           libxcursor
           libxdamage
           libxext
           libxfixes
           libxi
           libxrandr
           libxrender
           libxscrnsaver
           libxtst
           mesa
           nspr
           nss
           pango
           pulseaudio
           util-linux))
    (home-page "https://discord.com/")
    (synopsis "Voice, video, and text chat client")
    (description
     "Discord is a proprietary voice, video, and text communication client.
This package repackages Discord's prebuilt x86_64 Linux application and native
modules using the source versions pinned by Nixpkgs.")
    (license (license:non-copyleft "https://discord.com/terms"))))
