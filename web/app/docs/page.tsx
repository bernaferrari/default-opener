import Link from "next/link";
import {
  ArrowLeft,
  CheckCircle2,
  AlertTriangle,
  Download,
  Terminal,
  Settings,
  Command,
} from "lucide-react";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { Button } from "@/components/ui/button";

export default function DocsPage() {
  return (
    <>
      <Navbar />
      <main className="pt-32 pb-24 px-6 min-h-screen">
        <div className="max-w-3xl mx-auto">
          <Link
            href="/"
            className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-12 transition-colors group"
          >
            <ArrowLeft
              size={16}
              className="mr-2 group-hover:-translate-x-1 transition-transform"
            />
            Back to Home
          </Link>

          <header className="mb-16">
            <h1 className="text-4xl md:text-5xl font-bold mb-6 tracking-tight">
              Documentation
            </h1>
            <p className="text-xl text-muted-foreground leading-relaxed">
              Everything you need to know about taking control of your file
              associations on macOS.
            </p>
          </header>

          <article className="prose prose-neutral dark:prose-invert prose-lg max-w-none">
            <section className="mb-16">
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-blue-500/10 text-blue-500">
                  <Download size={24} />
                </div>
                <h2 className="text-2xl font-bold m-0">Installation</h2>
              </div>

              <div className="glass p-6 not-prose mb-6">
                <div className="flex flex-col md:flex-row gap-4 items-start md:items-center justify-between">
                  <div>
                    <h3 className="text-lg font-semibold mb-1">
                      Download Default Opener
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Latest version • macOS 14.0+ • Universal Binary
                    </p>
                  </div>
                  <Button asChild>
                    <a href="https://github.com/bernaferrari/default-opener/releases">
                      Download .dmg
                    </a>
                  </Button>
                </div>
              </div>

              <p>
                Once downloaded, simply drag the application to your{" "}
                <strong>Applications</strong> folder. Default Opener is signed
                and notarized by Apple, ready to run on Apple Silicon and Intel
                Macs.
              </p>
            </section>

            <section className="mb-16">
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-purple-500/10 text-purple-500">
                  <Settings size={24} />
                </div>
                <h2 className="text-2xl font-bold m-0">
                  Managing Associations
                </h2>
              </div>

              <p>
                The main interface organizes file types into intuitive
                categories. You can browse all extensions or search for a
                specific one (like <code>.pdf</code> or <code>.json</code>).
              </p>

              <ol className="space-y-2">
                <li>Launch Default Opener</li>
                <li>Navigate to the file type you want to change</li>
                <li>Click the dropdown menu next to the extension</li>
                <li>Select your preferred application from the list</li>
              </ol>

              <div className="not-prose glass p-4 my-6 mt-8 flex gap-4 items-start border-l-4 border-l-green-500">
                <CheckCircle2
                  className="text-green-500 shrink-0 mt-0.5"
                  size={20}
                />
                <div>
                  <h4 className="font-semibold text-foreground mb-1">
                    Pro Tip: Drag & Drop
                  </h4>
                  <p className="text-sm text-muted-foreground leading-relaxed">
                    You can drag any file from Finder and drop it onto the
                    Default Opener window to instantly jump to its settings.
                  </p>
                </div>
              </div>
            </section>

            <section className="mb-16">
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-pink-500/10 text-pink-500">
                  <Command size={24} />
                </div>
                <h2 className="text-2xl font-bold m-0">Bulk Editing</h2>
              </div>

              <p>
                Setting defaults one by one can be tedious. The{" "}
                <strong>Bulk Edit</strong> feature allows you to assign an
                application to multiple file types simultaneously.
              </p>

              <div className="glass p-6 not-prose mb-6 bg-muted/30">
                <h4 className="font-semibold mb-2">
                  Example: Setting VS Code for everything
                </h4>
                <p className="text-sm text-muted-foreground mb-4">
                  Easily set VS Code as the default editor for all programming
                  languages, config files, and text documents in one go.
                </p>
                <div className="flex gap-2 text-sm font-mono text-muted-foreground">
                  <span className="bg-background px-2 py-1 rounded border border-border">
                    .ts
                  </span>
                  <span className="bg-background px-2 py-1 rounded border border-border">
                    .js
                  </span>
                  <span className="bg-background px-2 py-1 rounded border border-border">
                    .json
                  </span>
                  <span className="bg-background px-2 py-1 rounded border border-border">
                    .css
                  </span>
                  <span className="text-muted-foreground/50">...</span>
                </div>
              </div>
            </section>

            <section className="mb-16">
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-orange-500/10 text-orange-500">
                  <Terminal size={24} />
                </div>
                <h2 className="text-2xl font-bold m-0">
                  URL Schemes & Protocols
                </h2>
              </div>

              <p>
                Beyond files, Default Opener manages URL schemes. This controls
                which app opens when you click a link.
              </p>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 not-prose">
                <div className="p-4 rounded-lg border border-border bg-card">
                  <code className="text-sm font-bold text-accent">
                    http/https
                  </code>
                  <p className="text-sm text-muted-foreground mt-1">
                    Default Web Browser
                  </p>
                </div>
                <div className="p-4 rounded-lg border border-border bg-card">
                  <code className="text-sm font-bold text-accent">mailto</code>
                  <p className="text-sm text-muted-foreground mt-1">
                    Email Client
                  </p>
                </div>
                <div className="p-4 rounded-lg border border-border bg-card">
                  <code className="text-sm font-bold text-accent">ssh</code>
                  <p className="text-sm text-muted-foreground mt-1">
                    Terminal / SSH Client
                  </p>
                </div>
                <div className="p-4 rounded-lg border border-border bg-card">
                  <code className="text-sm font-bold text-accent">slack</code>
                  <p className="text-sm text-muted-foreground mt-1">
                    Slack Workspace
                  </p>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-2xl font-bold mb-6">Troubleshooting</h2>

              <div className="not-prose glass p-6 border-destructive/20 bg-destructive/5">
                <div className="flex gap-4 items-start">
                  <AlertTriangle
                    className="text-destructive shrink-0 mt-1"
                    size={20}
                  />
                  <div>
                    <h3 className="font-semibold text-foreground mb-2">
                      Changes apply but revert after restart
                    </h3>
                    <p className="text-sm text-muted-foreground mb-4 leading-relaxed">
                      macOS Launch Services database can sometimes become
                      corrupted or cache old values aggressively. If you
                      experience persistent issues, try rebuilding the Launch
                      Services database.
                    </p>
                    <div className="bg-background/50 p-3 rounded-md border border-border/50 font-mono text-xs overflow-x-auto whitespace-nowrap">
                      /System/Library/Frameworks/CoreServices.framework/.../lsregister
                      -kill -r -domain local -domain system -domain user
                    </div>
                  </div>
                </div>
              </div>
            </section>
          </article>
        </div>
      </main>
      <Footer />
    </>
  );
}
