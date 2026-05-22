# System font set and the fontconfig fallback chain. Pin generic-family
# resolution explicitly so we don't depend on fontconfig priority order
# (which shifts as nixpkgs updates the priority of bundled fonts).

{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    comic-mono
    noto-fonts           # modern Latin/Cyrillic/Greek/Arabic/etc — replaces DejaVu as default
    noto-fonts-cjk-sans  # proper CJK rendering; without it kanji/hanzi fall back to Unifont bitmaps
    liberation_ttf       # metric-compatible Arial/Times/Courier — pages that name those fonts directly will lay out correctly
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Noto Sans" "Liberation Sans" ];
    serif     = [ "Noto Serif" "Liberation Serif" ];
    monospace = [ "Comic Mono" "Noto Sans Mono" ];
    emoji     = [ "Noto Color Emoji" ];
  };
}
