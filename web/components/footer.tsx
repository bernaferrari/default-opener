import Link from "next/link";

export function Footer() {
  return (
    <footer className="border-t border-border py-12 px-6">
      <div className="max-w-5xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
        <div className="text-center md:text-left">
          <span className="font-semibold">Default Opener</span>
          <p className="text-sm text-muted-foreground mt-1">
            Open source. Built with Swift.
          </p>
        </div>

        <div className="flex gap-6 text-sm text-muted-foreground">
          <Link
            href="/default-opener/docs"
            className="hover:text-foreground transition-colors"
          >
            Docs
          </Link>
          <a
            href="https://github.com/bernaferrari/default-opener"
            className="hover:text-foreground transition-colors"
          >
            GitHub
          </a>
          <a
            href="https://github.com/bernaferrari/default-opener/releases"
            className="hover:text-foreground transition-colors"
          >
            Releases
          </a>
        </div>
      </div>

      <div className="max-w-5xl mx-auto mt-8 pt-6 border-t border-border text-center">
        <p className="text-xs text-muted-foreground">
          © {new Date().getFullYear()} Default Opener. Apache 2.0 License.
        </p>
      </div>
    </footer>
  );
}
