# Perihelion: show fastfetch when a terminal window opens (as Veyl OS does).
# Only in interactive shells of a graphical terminal, never over SSH or on a
# text console, and once per window (shells started inside it inherit the
# marker and stay quiet).
# Turn it off: touch ~/.config/perihelion/no-fastfetch
case $- in
    *i*)
        if [ -z "${PERIHELION_FASTFETCH_SHOWN:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ] \
            && [ -z "${SSH_CONNECTION:-}" ] \
            && [ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/perihelion/no-fastfetch" ] \
            && command -v fastfetch >/dev/null 2>&1; then
            export PERIHELION_FASTFETCH_SHOWN=1
            fastfetch
        fi
        ;;
esac
