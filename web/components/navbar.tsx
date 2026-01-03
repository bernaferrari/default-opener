"use client";

import { Github } from "lucide-react";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";
import Link from "next/link";
import { ThemeToggle } from "@/components/theme-toggle";

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <nav
      className={cn(
        "fixed top-0 left-0 right-0 z-50 transition-all duration-300 border-b border-transparent",
        scrolled && "bg-background/80 backdrop-blur-md border-border"
      )}
    >
      <div className="max-w-5xl mx-auto px-6 h-16 flex items-center justify-between">
        <Link href="/" className="font-semibold text-lg">
          Default Opener
        </Link>

        <div className="flex items-center gap-5">
          <a
            href="#features"
            className="hidden sm:block text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            Features
          </a>
          <Link
            href="/default-opener/docs"
            className="hidden sm:block text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            Docs
          </Link>
          <div className="flex items-center gap-1">
            <a
              href="https://github.com/bernaferrari/default-opener"
              target="_blank"
              className="p-2 text-muted-foreground hover:text-foreground transition-colors"
            >
              <Github size={18} />
            </a>
            <ThemeToggle />
          </div>
        </div>
      </div>
    </nav>
  );
}
