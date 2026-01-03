import { Footer } from "@/components/footer";
import { Navbar } from "@/components/navbar";
import { Features } from "@/components/features";
import { Hero } from "@/components/hero";
import { Showcase } from "@/components/showcase";
import { Newsletter } from "@/components/newsletter";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <Features />
        <Showcase />
        <Newsletter />
      </main>
      <Footer />
    </>
  );
}
