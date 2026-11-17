// Served by the plugin in highlight.ts. Every value is highlighted HTML.
declare module "virtual:highlighted" {
  const highlighted: {
    samples: Record<string, { install: string; code: string }>;
    install: Record<string, string>;
    try: string;
    usage: string;
  };
  export default highlighted;
}
