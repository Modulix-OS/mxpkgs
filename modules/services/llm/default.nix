{ config, pkgs, pkgs-unstable, lib, ... }:
let
  cfg = config.mx.services.llm;

  llamaCppPackage =
    let
      base = pkgs-unstable.llama-cpp;
      computing = config.mx.hardware.gpu.compute.backend;
    in
      if computing == "cuda" then
        base.override { cudaSupport = true; }
      else if computing == "rocm" then
        pkgs-unstable.pkgsRocm.llama-cpp
      else if computing == "intel" then
        base.override { vulkanSupport = true; }
      else
        base;

  modelOptions = lib.types.submodule {
    options = {
      hf-repo = lib.mkOption { type = lib.types.str; description = "HuggingFace repo"; };
      hf-file = lib.mkOption { type = lib.types.str; description = "GGUF filename"; };
      alias = lib.mkOption { type = lib.types.str; description = "Model alias"; };
      ctx-size = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      temp = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      top-p = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      min-p = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      top-k = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      jinja = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      load-on-startup = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      stop-timeout = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      presence-penalty = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    };
  };

  modelsPresetIni =
    pkgs.writeText "llama-models.ini" (
      lib.generators.toINI { } (
        lib.mapAttrs (_: lib.filterAttrs (_: v: v != null)) cfg.modelsPreset
      )
    );
in
{
  options.mx.services.llm = {
    enable = lib.mkEnableOption "Enable local LLM service";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for llama-cpp server";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port for llama-cpp server";
    };

    ramOverflow = {
      enable = lib.mkEnableOption "GPU/RAM automatic layer overflow via llama.cpp -fit";

      marginMiB = lib.mkOption {
        type = lib.types.str;
        default = "1024";
        description = "Free VRAM margin per device left by -fit (--fit-target)";
      };

      minCtx = lib.mkOption {
        type = lib.types.str;
        default = "4096";
        description = "Floor context size -fit is allowed to shrink to (--fit-ctx)";
      };
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if cfg.ramOverflow.enable then
          [ "--parallel" "4" "-fa" "on" "-fit" "on" "--fit-target" cfg.ramOverflow.marginMiB "--fit-ctx" cfg.ramOverflow.minCtx ]
        else
          [ "-ngl" "99" "--parallel" "4" "-fa" "on" ];
      description = "Extra flags passed to llama-cpp";
    };

    modelsPreset = lib.mkOption {
      type = lib.types.attrsOf modelOptions;
      default = { };
      description = "Model presets for llama-cpp";
    };

    huggingfaceTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to agenix-encrypted HuggingFace token";
    };

    enableNewelle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Newelle GUI client";
    };

    open-webui = {
      enable = lib.mkEnableOption "Enable Open Webui service";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.open-webui;
        description = "Open WebUI package to use";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for open webui interface";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables for Open WebUI";
      };
    };

    llamaCppPackage = lib.mkOption {
      type = lib.types.package;
      default = llamaCppPackage;
      description = "llama-cpp package to use (auto-selected by GPU backend)";
    };
  };

  config = lib.mkIf cfg.enable {

    mx.hardware.gpu.compute.enable = true;

    environment.systemPackages = lib.mkIf cfg.enableNewelle [
      pkgs-unstable.newelle
    ];

    services.open-webui = {
      package = lib.mkMxDefault cfg.open-webui.package;
      enable = cfg.open-webui.enable;
      port = lib.mkMxDefault cfg.open-webui.port;
      environment = {
        OLLAMA_BASE_URL = lib.mkMxDefault "";
        OPENAI_API_BASE_URL = lib.mkMxDefault "http://${cfg.host}:${toString cfg.port}/v1";
        OPENAI_API_KEY = lib.mkMxDefault "none";
      } // cfg.open-webui.extraEnvironment;
    };

    services.llama-cpp = {
      enable = true;
      package = lib.mkMxDefault cfg.llamaCppPackage;
      host = lib.mkMxDefault cfg.host;
      port = lib.mkMxDefault cfg.port;
      extraFlags =
        cfg.extraFlags
        ++ lib.optionals (cfg.modelsPreset != { }) [ "--models-preset" "${modelsPresetIni}" ];
    };

    systemd.services.llama-cpp = {
      serviceConfig = {
        EnvironmentFile = lib.mkIf (cfg.huggingfaceTokenFile != null) (lib.mkMxDefault cfg.huggingfaceTokenFile);
      };
    };
  };
}
