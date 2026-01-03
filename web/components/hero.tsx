"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import { Apple, Github } from "lucide-react";
import { Button } from "@/components/ui/button";

export function Hero() {
  return (
    <section className="relative hero-gradient">
      <div className="max-w-5xl mx-auto px-6 pt-32 pb-24 text-center">
        {/* Badge */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-border bg-card text-sm text-muted-foreground mb-8"
        >
          <span className="w-2 h-2 rounded-full bg-green-500" />
          Free & Open Source
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold tracking-tight mb-6 leading-[1.1]"
        >
          Take control of your{" "}
          <span className="text-gradient whitespace-nowrap">
            file associations
          </span>
        </motion.h1>

        {/* Description */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-10 leading-relaxed"
        >
          Stop apps from hijacking your defaults. Manage 100+ file types and URL
          schemes — all from one place.
        </motion.p>

        {/* CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-4"
        >
          <Button size="lg" asChild>
            <a
              href="https://github.com/bernaferrari/default-opener/releases"
              target="_blank"
            >
              <Apple />
              Download for Mac
            </a>
          </Button>
          <Button variant="outline" size="lg" asChild>
            <a
              href="https://github.com/bernaferrari/default-opener"
              target="_blank"
            >
              <Github />
              View on GitHub
            </a>
          </Button>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="text-sm text-muted-foreground mb-16"
        >
          Requires macOS 14.0+ · Apple Silicon & Intel
        </motion.p>

        {/* Screenshot */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.5 }}
          className="screenshot-container max-w-4xl mx-auto"
        >
          <div className="screenshot-inner">
            <Image
              src="/default-opener/assets/header.png"
              alt="Default Opener - Main Interface"
              width={1400}
              height={900}
              priority
              className="w-full h-auto"
            />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
