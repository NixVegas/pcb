{
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "kicad-text-injector";
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "hoijui";
    repo = "kicad-text-injector";
    tag = finalAttrs.version;
    hash = "sha256-3m9tcvFf6v6Yxj2svpzZfhzHWzBEnXpB6HQGGOF8tVQ=";
  };

  cargoHash = "sha256-EPKOCvyD7MpBFQO7h5qB14jlMcaPjg3G1HC9BfXyXo8=";
})
