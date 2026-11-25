import { ComponentShowcase } from "@/app/_components/component-showcase"
import { Container } from "@/components/layout/container"
import { siteConfig } from "@/lib/site"

export default function Home() {
  return (
    <Container className="flex flex-col gap-12 py-12">
      <div className="flex flex-col gap-3">
        <h1 className="text-3xl font-semibold tracking-tight">{siteConfig.name}</h1>
        <p className="text-muted-foreground">{siteConfig.description}</p>
      </div>
      <ComponentShowcase />
    </Container>
  )
}
