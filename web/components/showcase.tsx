"use client";

import { motion } from "framer-motion";
import Image from "next/image";

export function Showcase() {
  return (
    <section id="how-it-works" className="py-24 px-6 border-t border-border">
      <div className="max-w-5xl mx-auto">
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            See it in action
          </h2>
          <p className="text-muted-foreground text-lg max-w-xl mx-auto">
            A clean, native interface that feels right at home on macOS.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-2 gap-6">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="glass overflow-hidden"
          >
            <div className="p-4 border-b border-border">
              <h3 className="font-semibold">URL Schemes</h3>
              <p className="text-sm text-muted-foreground">
                Control system protocols
              </p>
            </div>
            <div className="p-2">
              <Image
                src="/default-opener/assets/url-schemes.png"
                alt="URL Schemes"
                width={600}
                height={400}
                className="rounded-lg w-full h-auto"
              />
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="glass overflow-hidden"
          >
            <div className="p-4 border-b border-border">
              <h3 className="font-semibold">Bulk Edit by App</h3>
              <p className="text-sm text-muted-foreground">
                Change multiple types at once
              </p>
            </div>
            <div className="p-2">
              <Image
                src="/default-opener/assets/change-all-from-app.png"
                alt="Change All From App"
                width={600}
                height={400}
                className="rounded-lg w-full h-auto"
              />
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
