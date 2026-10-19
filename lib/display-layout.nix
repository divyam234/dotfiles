{ lib }:
let
  round = value: builtins.floor (value + 0.5);

  modeWidth =
    output:
    let
      mode =
        output.mode or (throw "Active output ${output.name} needs mode to generate logical position");
      match = builtins.match "([0-9]+)x[0-9]+.*" mode;
    in
    if match == null then
      throw "Output ${output.name} has invalid mode: ${mode}"
    else
      builtins.fromJSON (builtins.elemAt match 0);

  normalize =
    scaleOf: outputs:
    let
      appendOutput =
        state: output:
        let
          active = !(output.off or false);
          width = if active then round (modeWidth output / scaleOf output) else null;
          position =
            if output.position or null != null then
              output.position
            else if active then
              {
                inherit (state) x;
                y = 0;
              }
            else
              null;
        in
        {
          x = if active then position.x + width else state.x;
          outputs = state.outputs ++ [ (output // { inherit position; }) ];
        };
    in
    (builtins.foldl' appendOutput {
      x = 0;
      outputs = [ ];
    } outputs).outputs;
in
host:
let
  outputs = normalize (output: output.scale or 1.0) (host.outputs or [ ]);
  greeterScale = host.greeter.output.scale or 1.25;
  greeterOutputs = normalize (_: greeterScale) (host.outputs or [ ]);
  activeGreeterOutputs = builtins.filter (output: !(output.off or false)) greeterOutputs;
in
{
  inherit greeterScale outputs;
  greeterLayout = lib.concatStringsSep "; " (
    map (
      output: "${output.name}:${toString output.position.x},${toString output.position.y}"
    ) activeGreeterOutputs
  );
}
