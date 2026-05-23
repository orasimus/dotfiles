{ pkgs, ... }:
let
  # Finnish piper TTS voice. The .onnx model and its .json config must sit in
  # the same directory at runtime (piper derives the json path from the model
  # path), so wrap both fetchurl results in a single store dir via symlinks.
  harriVoice = let
    onnx = pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/fi/fi_FI/harri/medium/fi_FI-harri-medium.onnx";
      sha256 = "1293zg0785vhfyzcwfsrn9k254imrjgi7bgwwi0dkbjclgx6fhd4";
    };
    json = pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/fi/fi_FI/harri/medium/fi_FI-harri-medium.onnx.json";
      sha256 = "0vcip1sbx9myif0ddzsywibhfqfn2zm1xr3rfaz1zpsayxv9z71z";
    };
  in pkgs.runCommand "fi_FI-harri-medium" { } ''
    mkdir -p $out
    ln -s ${onnx} $out/fi_FI-harri-medium.onnx
    ln -s ${json} $out/fi_FI-harri-medium.onnx.json
  '';

  # Speak the current 24h wall-clock time in Finnish through piper. Hours read
  # as a single number (18 → "kahdeksantoista"); minutes also as a number, but
  # single-digit minutes get a "nolla" prefix to mirror how a digital readout
  # is spoken aloud (18:05 → "kahdeksantoista nolla viisi"). Tens 20-50 are
  # split from the ones with a space (35 → "kolmekymmentä viisi").
  kello = pkgs.writeShellApplication {
    name = "kello";
    runtimeInputs = with pkgs; [ piper-tts alsa-utils coreutils ];
    text = ''
      ones=( [0]="nolla" [1]="yksi" [2]="kaksi" [3]="kolme" [4]="neljä"
             [5]="viisi" [6]="kuusi" [7]="seitsemän" [8]="kahdeksan" [9]="yhdeksän" )

      teens=( [10]="kymmenen" [11]="yksitoista" [12]="kaksitoista" [13]="kolmetoista"
              [14]="neljätoista" [15]="viisitoista" [16]="kuusitoista"
              [17]="seitsemäntoista" [18]="kahdeksantoista" [19]="yhdeksäntoista" )

      tens=( [2]="kaksikymmentä" [3]="kolmekymmentä" [4]="neljäkymmentä" [5]="viisikymmentä" )

      say_number() {
        local n="$1"
        if (( n < 10 )); then
          printf '%s' "''${ones[n]}"
        elif (( n < 20 )); then
          printf '%s' "''${teens[n]}"
        else
          local t=$(( n / 10 )) o=$(( n % 10 ))
          if (( o == 0 )); then
            printf '%s' "''${tens[t]}"
          else
            printf '%s %s' "''${tens[t]}" "''${ones[o]}"
          fi
        fi
      }

      h=$(date +%-H)
      m=$(date +%-M)

      hour_word=$(say_number "$h")
      if (( m < 10 )); then
        min_words="nolla $(say_number "$m")"
      else
        min_words=$(say_number "$m")
      fi

      text="Kello on $hour_word $min_words"

      printf '%s\n' "$text" \
        | piper --model ${harriVoice}/fi_FI-harri-medium.onnx --output_raw 2>/dev/null \
        | aplay -q -r 22050 -f S16_LE -t raw -
    '';
  };
in
{
  home.packages = [ kello ];

  wayland.windowManager.hyprland.settings.bind = [
    "SUPER, T, exec, kello"
  ];
}
