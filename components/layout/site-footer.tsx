import { Container } from "@/components/layout/container"
import { siteConfig } from "@/lib/site"

export function SiteFooter() {
  return (
    <footer className="border-t py-6 text-sm text-muted-foreground">
      <Container>
        © {siteConfig.name}
      </Container>
    </footer>
  )
}
