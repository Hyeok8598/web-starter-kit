"use client"

import { Bell, Info } from "lucide-react"
import type { ReactNode } from "react"
import { toast } from "sonner"

import { Button, buttonVariants } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import { Skeleton } from "@/components/ui/skeleton"

// 섹션 공통 래퍼 (이 파일 내부에서만 사용)
function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-4">
      <h2 className="text-lg font-semibold">{title}</h2>
      <Separator />
      {children}
    </section>
  )
}

// 컴포넌트 사용 예시 모음. 새 프로젝트에서는 이 폴더째 삭제해도 무방
export function ComponentShowcase() {
  return (
    <div className="flex flex-col gap-10">
      <Section title="Button">
        <div className="flex flex-wrap gap-2">
          <Button>Default</Button>
          <Button variant="secondary">Secondary</Button>
          <Button variant="outline">Outline</Button>
          <Button variant="ghost">Ghost</Button>
          <Button variant="destructive">Destructive</Button>
          <Button variant="link">Link</Button>
          <Button size="icon" aria-label="알림">
            <Bell />
          </Button>
        </div>
      </Section>

      <Section title="Input / Label">
        <div className="grid w-full max-w-sm gap-2">
          <Label htmlFor="showcase-email">이메일</Label>
          <Input id="showcase-email" type="email" placeholder="name@example.com" />
        </div>
      </Section>

      <Section title="Card">
        <Card className="max-w-sm">
          <CardHeader>
            <CardTitle>카드 제목</CardTitle>
            <CardDescription>카드 설명 영역입니다.</CardDescription>
          </CardHeader>
          <CardContent>본문 내용이 들어갑니다.</CardContent>
          <CardFooter>
            <Button size="sm">확인</Button>
          </CardFooter>
        </Card>
      </Section>

      <Section title="Dialog / Sheet / Dropdown">
        <div className="flex flex-wrap gap-2">
          <Dialog>
            <DialogTrigger className={buttonVariants({ variant: "outline" })}>
              Dialog 열기
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Dialog 제목</DialogTitle>
                <DialogDescription>확인이 필요한 작업에 사용합니다.</DialogDescription>
              </DialogHeader>
              <DialogFooter showCloseButton />
            </DialogContent>
          </Dialog>

          <Sheet>
            <SheetTrigger className={buttonVariants({ variant: "outline" })}>
              Sheet 열기
            </SheetTrigger>
            <SheetContent>
              <SheetHeader>
                <SheetTitle>Sheet 제목</SheetTitle>
                <SheetDescription>모바일 메뉴, 필터 패널 등에 사용합니다.</SheetDescription>
              </SheetHeader>
            </SheetContent>
          </Sheet>

          <DropdownMenu>
            <DropdownMenuTrigger className={buttonVariants({ variant: "outline" })}>
              Dropdown 열기
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuItem>항목 1</DropdownMenuItem>
              <DropdownMenuItem>항목 2</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </Section>

      <Section title="Toast (Sonner)">
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => toast("기본 알림입니다.")}>
            <Info /> 기본
          </Button>
          <Button variant="outline" onClick={() => toast.success("저장되었습니다.")}>
            성공
          </Button>
          <Button variant="outline" onClick={() => toast.error("오류가 발생했습니다.")}>
            에러
          </Button>
        </div>
      </Section>

      <Section title="Skeleton">
        <div className="flex items-center gap-3">
          <Skeleton className="size-12 rounded-full" />
          <div className="flex flex-col gap-2">
            <Skeleton className="h-4 w-48" />
            <Skeleton className="h-4 w-32" />
          </div>
        </div>
      </Section>
    </div>
  )
}
