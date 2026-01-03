import type { Metadata } from "next";
import { Outfit } from "next/font/google";
import "./globals.css";
import { cn } from "@/lib/utils";
import { ThemeProvider } from "@/components/theme-provider";

const outfit = Outfit({
  subsets: ["latin"],
  variable: "--font-outfit",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Default Opener – Take Control of Your File Associations",
  description:
    "Stop apps from hijacking your defaults. Manage 100+ file types and URL schemes — all from one place.",
  metadataBase: new URL("https://bernaferrari.github.io"),
  openGraph: {
    type: "website",
    url: "https://bernaferrari.github.io/default-opener/",
    title: "Default Opener – Take Control",
    description:
      "Stop apps from hijacking your defaults. Manage 100+ file types and URL schemes.",
    images: [{ url: "/default-opener/assets/header.png" }],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={cn(outfit.variable, "antialiased min-h-screen")}>
        <ThemeProvider
          attribute="class"
          defaultTheme="dark"
          enableSystem
          disableTransitionOnChange
        >
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
