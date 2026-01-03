"use client";

import { motion } from "framer-motion";
import {
  FileType2,
  Link2,
  Layers3,
  RotateCcw,
  ShieldCheck,
  HardDriveDownload,
} from "lucide-react";

const features = [
  {
    icon: FileType2,
    title: "100+ File Types",
    description: (
      <>Documents, code, images, videos — manage them all in one place.</>
    ),
  },
  {
    icon: Link2,
    title: "URL Schemes",
    description: (
      <>
        Control <code>http</code>, <code>mailto</code>, <code>ssh</code>, and
        custom protocols.
      </>
    ),
  },
  {
    icon: Layers3,
    title: "Bulk Edit",
    description: <>Select multiple types and change defaults at once.</>,
  },
  {
    icon: HardDriveDownload,
    title: "Backup & Restore",
    description: <>Export your preferences and restore on any Mac.</>,
  },
  {
    icon: RotateCcw,
    title: "Instant Undo",
    description: <>One-click undo via toast when you make a mistake.</>,
  },
  {
    icon: ShieldCheck,
    title: "Hijack Detection",
    description: <>Get alerts when apps change your defaults silently.</>,
  },
];

export function Features() {
  return (
    <section id="features" className="py-24 px-6">
      <div className="max-w-5xl mx-auto">
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Powerful & Simple
          </h2>
          <p className="text-muted-foreground text-lg max-w-xl mx-auto">
            All the tools you need to manage file and URL associations.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {features.map((feature, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: index * 0.05 }}
              className="glass feature-card p-6"
            >
              <div className="w-10 h-10 rounded-lg bg-blue-500/10 flex items-center justify-center mb-4 text-blue-500">
                <feature.icon size={20} strokeWidth={1.5} />
              </div>
              <h3 className="font-semibold mb-2">{feature.title}</h3>
              <p className="text-sm text-muted-foreground leading-relaxed [&_code]:bg-muted [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:rounded [&_code]:text-xs [&_code]:font-mono">
                {feature.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
