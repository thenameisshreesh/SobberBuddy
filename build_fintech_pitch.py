"""Board pitch PDF: 10-minute FinTech recommendation."""

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, Color
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_JUSTIFY, TA_CENTER, TA_RIGHT
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, NextPageTemplate, PageBreak,
    Paragraph, Spacer, Table, TableStyle, KeepTogether, CondPageBreak,
    ListFlowable, ListItem, HRFlowable, Flowable,
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas

OUT = r"m:\me\Projects\SoberBuddyF\FinTech_Bank_Management_Pitch.pdf"

NAVY = HexColor("#0B1F3A")
NAVY2 = HexColor("#14304F")
TEAL = HexColor("#1B6B66")
TEAL_SOFT = HexColor("#E6F2F1")
GOLD = HexColor("#A68456")
CREAM = HexColor("#F6F3EC")
INK = HexColor("#1C2430")
MUTED = HexColor("#5C6774")
RULE = HexColor("#E2DCD0")
CARD = HexColor("#F8F6F2")
RED_SOFT = HexColor("#F8EFEA")
AMBER = HexColor("#8A5A2A")

PAGE_W, PAGE_H = A4


class ColoredBox(Flowable):
    def __init__(self, contents, width, fill, border=None, pad=8, radius=4):
        super().__init__()
        self.contents = contents
        self.box_width = width
        self.fill = fill
        self.border = border
        self.pad = pad
        self.radius = radius
        self._inner_h = 0

    def wrap(self, aw, ah):
        w = self.box_width
        inner_w = w - 2 * self.pad
        y = 0
        heights = []
        for c in self.contents:
            cw, ch = c.wrap(inner_w, ah)
            heights.append(ch)
            y += ch
        self._heights = heights
        self._inner_h = y
        self.width = w
        self.height = y + 2 * self.pad
        return self.width, self.height

    def draw(self):
        c = self.canv
        c.saveState()
        c.setFillColor(self.fill)
        if self.border:
            c.setStrokeColor(self.border)
            c.setLineWidth(0.6)
            c.roundRect(0, 0, self.width, self.height, self.radius, fill=1, stroke=1)
        else:
            c.setStrokeColor(self.fill)
            c.roundRect(0, 0, self.width, self.height, self.radius, fill=1, stroke=0)
        c.restoreState()
        inner_w = self.width - 2 * self.pad
        y = self.height - self.pad
        for flow, h in zip(self.contents, self._heights):
            y -= h
            flow.drawOn(c, self.pad, y)


def header_footer(canv, doc):
    canv.saveState()
    canv.setFillColor(NAVY)
    canv.rect(0, PAGE_H - 12 * mm, PAGE_W, 12 * mm, fill=1, stroke=0)
    canv.setFillColor(GOLD)
    canv.rect(0, PAGE_H - 12.8 * mm, PAGE_W, 0.8 * mm, fill=1, stroke=0)
    canv.setFillColor(white)
    canv.setFont("Times-Bold", 8)
    canv.drawString(18 * mm, PAGE_H - 7.6 * mm, "MANAGEMENT PITCH")
    canv.setFont("Times-Roman", 8)
    canv.drawRightString(PAGE_W - 18 * mm, PAGE_H - 7.6 * mm, "Ten minutes  ·  October 2026")

    canv.setFillColor(NAVY)
    canv.rect(0, 0, PAGE_W, 10 * mm, fill=1, stroke=0)
    canv.setFillColor(HexColor("#D5D8DE"))
    canv.setFont("Times-Roman", 8)
    canv.drawString(18 * mm, 4.2 * mm, "Recommendation to bank management")
    canv.drawRightString(PAGE_W - 18 * mm, 4.2 * mm, f"{doc.page}")
    canv.restoreState()


def cover_page(canv, doc):
    canv.saveState()
    canv.setFillColor(NAVY)
    canv.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    canv.setFillColor(GOLD)
    canv.rect(0, PAGE_H - 8 * mm, PAGE_W, 8 * mm, fill=1, stroke=0)
    canv.setFillColor(TEAL)
    canv.rect(0, 0, PAGE_W, 28 * mm, fill=1, stroke=0)

    canv.setFillColor(GOLD)
    canv.setFont("Times-Bold", 9)
    canv.drawString(20 * mm, 252 * mm, "BOARD RECOMMENDATION")

    canv.setFillColor(white)
    canv.setFont("Times-Bold", 28)
    y = 232 * mm
    for line in [
        "How this bank should",
        "compete in a FinTech",
        "industry",
    ]:
        canv.drawString(20 * mm, y, line)
        y -= 13 * mm

    canv.setStrokeColor(GOLD)
    canv.setLineWidth(1)
    canv.line(20 * mm, 188 * mm, 72 * mm, 188 * mm)

    canv.setFillColor(HexColor("#D5DDE8"))
    canv.setFont("Times-Italic", 12)
    canv.drawString(20 * mm, 178 * mm, "A ten-minute spoken pitch for management")

    questions = [
        "How should the bank position in the industry?",
        "What should the bank invest in?",
        "Which opportunities to take, and how to manage the risk?",
        "What will let the bank thrive in the next three to five years?",
    ]
    qy = 154 * mm
    for i, q in enumerate(questions, 1):
        canv.setFillColor(GOLD)
        canv.setFont("Times-Bold", 12)
        canv.drawString(20 * mm, qy, f"{i}")
        canv.setFillColor(white)
        canv.setFont("Times-Roman", 12.5)
        canv.drawString(30 * mm, qy, q)
        qy -= 16 * mm

    box_h = 34 * mm
    box_y = 40 * mm
    canv.setFillColor(NAVY2)
    canv.roundRect(18 * mm, box_y, PAGE_W - 36 * mm, box_h, 3 * mm, fill=1, stroke=0)
    canv.setFillColor(GOLD)
    canv.rect(18 * mm, box_y, 1.6 * mm, box_h, fill=1, stroke=0)
    canv.setFont("Times-Bold", 8)
    canv.setFillColor(GOLD)
    canv.drawString(26 * mm, box_y + 25 * mm, "THE POSITION TO APPROVE")
    canv.setFillColor(white)
    canv.setFont("Times-Bold", 13)
    canv.drawString(26 * mm, box_y + 15 * mm, "Trusted digital relationship bank")
    canv.setFont("Times-Roman", 10)
    canv.setFillColor(HexColor("#D5DDE8"))
    canv.drawString(
        26 * mm, box_y + 7 * mm,
        "Keep the customer, the deposit, and the credit judgment.",
    )

    canv.setFillColor(HexColor("#D7EBE9"))
    canv.setFont("Times-Roman", 9)
    canv.drawString(20 * mm, 16 * mm, "Read aloud at a board pace. The spoken text is timed to ten minutes.")
    canv.setFillColor(white)
    canv.setFont("Times-Roman", 9)
    canv.drawString(20 * mm, 10 * mm, "Evidence: DBS, Nubank, Revolut, WeBank, JPMorgan, Deutsche Bank  ·  KPMG, Finastra, McKinsey, BIS")
    canv.restoreState()


def make_styles():
    ss = getSampleStyleSheet()
    styles = {}
    styles["h1"] = ParagraphStyle(
        "h1", fontName="Times-Bold", fontSize=16, leading=19,
        textColor=NAVY, spaceBefore=2, spaceAfter=6,
    )
    styles["h2"] = ParagraphStyle(
        "h2", fontName="Times-Bold", fontSize=12.5, leading=15,
        textColor=TEAL, spaceBefore=8, spaceAfter=4,
    )
    styles["time"] = ParagraphStyle(
        "time", fontName="Times-Bold", fontSize=8.5, leading=11,
        textColor=GOLD, spaceBefore=10, spaceAfter=1, tracking=0.4,
    )
    styles["body"] = ParagraphStyle(
        "body", fontName="Times-Roman", fontSize=10.5, leading=14.2,
        textColor=INK, alignment=TA_JUSTIFY, spaceAfter=7,
    )
    styles["body_first"] = ParagraphStyle(
        "body_first", parent=styles["body"], spaceBefore=2,
    )
    styles["small"] = ParagraphStyle(
        "small", fontName="Times-Roman", fontSize=9, leading=12,
        textColor=INK, alignment=TA_LEFT, spaceAfter=3,
    )
    styles["small_muted"] = ParagraphStyle(
        "small_muted", fontName="Times-Italic", fontSize=8.5, leading=11,
        textColor=MUTED, spaceAfter=2,
    )
    styles["label"] = ParagraphStyle(
        "label", fontName="Times-Bold", fontSize=8, leading=10,
        textColor=TEAL, spaceBefore=0, spaceAfter=2,
    )
    styles["card_title"] = ParagraphStyle(
        "card_title", fontName="Times-Bold", fontSize=10, leading=13,
        textColor=NAVY, spaceAfter=2,
    )
    styles["card_body"] = ParagraphStyle(
        "card_body", fontName="Times-Roman", fontSize=9, leading=12,
        textColor=INK, alignment=TA_LEFT,
    )
    styles["th"] = ParagraphStyle(
        "th", fontName="Times-Bold", fontSize=8, leading=10.5,
        textColor=white,
    )
    styles["td"] = ParagraphStyle(
        "td", fontName="Times-Roman", fontSize=8, leading=10.5,
        textColor=INK,
    )
    styles["td_b"] = ParagraphStyle(
        "td_b", fontName="Times-Bold", fontSize=8, leading=10.5,
        textColor=NAVY,
    )
    styles["src"] = ParagraphStyle(
        "src", fontName="Times-Roman", fontSize=8.5, leading=11.4,
        textColor=INK, leftIndent=0, spaceAfter=4,
    )
    styles["footer_note"] = ParagraphStyle(
        "footer_note", fontName="Times-Italic", fontSize=8.5, leading=11,
        textColor=MUTED, spaceBefore=4,
    )
    styles["ask"] = ParagraphStyle(
        "ask", fontName="Times-Bold", fontSize=10.5, leading=14,
        textColor=NAVY, spaceAfter=4,
    )
    return styles


S = make_styles()


def P(text, style="body"):
    return Paragraph(text, S[style])


def section_banner(minute, title):
    data = [[
        Paragraph(minute, ParagraphStyle("m", fontName="Times-Bold", fontSize=8, leading=10, textColor=NAVY)),
        Paragraph(title, ParagraphStyle("t", fontName="Times-Bold", fontSize=11, leading=13, textColor=white)),
    ]]
    t = Table(data, colWidths=[28 * mm, 146 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, 0), GOLD),
        ("BACKGROUND", (1, 0), (1, 0), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (0, 0), 6),
        ("RIGHTPADDING", (0, 0), (0, 0), 6),
        ("LEFTPADDING", (1, 0), (1, 0), 8),
        ("RIGHTPADDING", (1, 0), (1, 0), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return t


def callout(title, body, fill=TEAL_SOFT):
    width = 174 * mm
    return ColoredBox(
        [Paragraph(title, S["card_title"]), Paragraph(body, S["card_body"])],
        width, fill, pad=8, radius=3,
    )


def build():
    doc = BaseDocTemplate(
        OUT, pagesize=A4,
        leftMargin=18 * mm, rightMargin=18 * mm,
        topMargin=18 * mm, bottomMargin=16 * mm,
        title="How this bank should compete in a FinTech industry",
        author="Management recommendation",
    )
    frame_cover = Frame(0, 0, PAGE_W, PAGE_H, id="cover", showBoundary=0)
    frame = Frame(
        18 * mm, 14 * mm, PAGE_W - 36 * mm, PAGE_H - 30 * mm,
        id="body", showBoundary=0,
    )
    doc.addPageTemplates([
        PageTemplate(id="cover", frames=[frame_cover], onPage=cover_page),
        PageTemplate(id="main", frames=[frame], onPage=header_footer),
    ])

    story = []
    story.append(NextPageTemplate("main"))
    story.append(PageBreak())

    # ----- running order -----
    story.append(P("Running order", "h1"))
    story.append(P(
        "This document is the speech. Read it aloud, without the tables, and it fills ten minutes. "
        "The tables are the leave-behind for the discussion that follows.",
        "body_first",
    ))

    rows = [[
        Paragraph("Clock", S["th"]),
        Paragraph("Question the board asked", S["th"]),
        Paragraph("What you decide", S["th"]),
    ]]
    order = [
        ("0:00–1:00", "Set the industry choice", "Four models exist. Copy the discipline, not the costume."),
        ("1:00–2:30", "1. How do we position?", "Trusted digital relationship bank. Not a super-app."),
        ("2:30–5:00", "2. What do we invest in?", "Six layers, in order, with a capital split."),
        ("5:00–7:30", "3. Which opportunities, and the risk?", "Five bets, each with a stop-rule."),
        ("7:30–9:20", "4. How do we thrive in 3–5 years?", "A three-stage sequence and one accountable executive."),
        ("9:20–10:00", "The ask", "Three decisions. No vendor selection today."),
    ]
    for a, b, c in order:
        rows.append([
            Paragraph(a, S["td_b"]),
            Paragraph(b, S["td"]),
            Paragraph(c, S["td"]),
        ])
    tbl = Table(rows, colWidths=[28 * mm, 62 * mm, 84 * mm])
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("BACKGROUND", (0, 1), (-1, 1), CREAM),
        ("BACKGROUND", (0, 2), (-1, 2), white),
        ("BACKGROUND", (0, 3), (-1, 3), CREAM),
        ("BACKGROUND", (0, 4), (-1, 4), white),
        ("BACKGROUND", (0, 5), (-1, 5), CREAM),
        ("BACKGROUND", (0, 6), (-1, 6), TEAL_SOFT),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(tbl)
    story.append(Spacer(1, 4 * mm))
    story.append(callout(
        "The recommendation in one line",
        "Be the trusted digital relationship bank for households and small businesses: keep deposits, credit judgment, and the customer; distribute through a few embedded journeys; fund data, resilience, and artificial intelligence in that order; and give one executive three years to ship it under explicit risk limits.",
    ))

    # ----- speech -----
    story.append(Spacer(1, 6 * mm))
    story.append(section_banner("0:00", "Open  ·  four models, one choice"))
    story.append(Spacer(1, 3 * mm))
    story.append(P(
        "Good morning. I have one recommendation. The industry does not need another list of FinTech tools. It needs a position this bank can defend for the next five years."
    ))
    story.append(P(
        "Four institutions show the choice. DBS in Singapore rebuilt data, cloud, and culture, then placed the bank inside home, car, and small-business journeys. It calls that invisible banking. Nubank in Brazil won on simple, fairer pricing, then moved customers from a card into credit, savings, and investments. Revolut built a super-app of foreign exchange, investing, and lifestyle. WeBank, inside Tencent, underwrites small credit with artificial intelligence and no branches. JPMorgan is the scale incumbent: proprietary platforms, used inside the bank first. Deutsche Bank’s API programme, since 2015, lets partners embed payments and accounts where the customer already is."
    ))
    story.append(P(
        "These are four strategies, not one trend. We should copy the discipline, not the costume."
    ))

    story.append(Spacer(1, 2 * mm))
    story.append(section_banner("1:00", "1  ·  How should the bank position?"))
    story.append(Spacer(1, 3 * mm))
    story.append(P(
        "Position this bank as the trusted digital relationship bank for households and small businesses. Regulated. Data-intelligent. Present where the customer already decides."
    ))
    story.append(P(
        "Three commitments make that position real."
    ))
    story.append(P(
        "We keep the primary relationship. Deposits, payments, credit judgment, and advice stay with us. A partner may introduce the customer. We still hold the account and the risk."
    ))
    story.append(P(
        "We distribute through other companies’ journeys when that is where the decision happens. Embedded finance is a distribution channel. It is not permission to become a silent utility with no price power. DBS embedded into everyday journeys and still owned the banking product. That is the pattern."
    ))
    story.append(P(
        "We compete on trust and speed together. KPMG’s CEO outlook finds 83 percent of bank chief executives confident about growth over three years, and clear that the asset to protect is trust. Nubank grew where incumbents felt unfair. Revolut grew where incumbents felt slow. Safe and slow loses. Fast and careless loses."
    ))
    story.append(P(
        "We will not build a lifestyle super-app. We do not have that cost base, and a thin copy would spend the trust we are compounding. We will not call new paint on a forty-year core a transformation. DBS broke through on operating model and data, not on advertising."
    ))
    story.append(P(
        "The line I want this bank to earn is short. The safest place to keep money, and the fastest useful place to use it."
    ))

    story.append(Spacer(1, 2 * mm))
    story.append(section_banner("2:30", "2  ·  What should the bank invest in?"))
    story.append(Spacer(1, 3 * mm))
    story.append(P(
        "Invest in a stack, in order. KPMG’s 2026 technology survey puts data, cybersecurity, fraud, digital experience, and modernization first. Finastra’s 2026 survey, across eleven markets, finds the sector past pilots: 87 percent will invest in modernization this year, and 54 percent partner with a fintech rather than build every piece. Security spend is expected to rise about 40 percent. Cloud, named by 29 percent, is the layer underneath."
    ))
    story.append(P("Six investments follow."))
    story.append(P(
        "First, data and a core renewed in slices. In KPMG’s 2025 survey, the barriers are privacy and risk at 93 percent, data quality at 89, and legacy integration at 81. Until customer, payment, and credit data are clean, consented, and usable, later projects stay pilots."
    ))
    story.append(P(
        "Second, cybersecurity, fraud, and resilience. Eighty-nine percent of those banks are raising cyber budgets, while 73 percent say they are prepared for an attack. Preparation on paper is not resilience on a Friday night. This spend protects the position."
    ))
    story.append(P(
        "Third, artificial intelligence with a measured result. Sixty-five percent of bank CEOs call it a top priority, and 59 percent expect agentic systems to matter. Ship it where loss and cost are already counted: real-time fraud, small-business credit support, contact-centre assistance, and compliance monitoring. Advice to customers waits until the model is governed."
    ))
    story.append(P(
        "Fourth, mobile and messaging as the front door. The same survey puts online, mobile, and message channels at 96, 95, and 95 percent. A customer should open, pay, see a clear credit decision, and understand a fee without a branch."
    ))
    story.append(P(
        "Fifth, payments that finish in seconds, at home and across borders. McKinsey’s 2025 payments report treats interoperable rails as infrastructure, with intelligence at the moment of payment. If our rail is overnight, a partner will not wait."
    ))
    story.append(P(
        "Sixth, a few deep partnerships, and the people who run them. Partner for identity, connectivity, and vertical software. Build what compounds: risk models, the relationship, and the balance sheet."
    ))
    story.append(P(
        "Split incremental technology capital over three years: 30 percent data and core, 20 percent cyber and fraud, 20 percent artificial intelligence with a published outcome, 15 percent channels and embedded distribution, 10 percent payments, 5 percent partners and hiring. Review it every six months. Stop anything that cannot name the customer result and the risk owner."
    ))

    story.append(Spacer(1, 3 * mm))
    story.append(P("Leave-behind: where the money goes", "h2"))
    cap_rows = [[
        Paragraph("Share", S["th"]),
        Paragraph("Investment", S["th"]),
        Paragraph("Done when", S["th"]),
    ]]
    caps = [
        ("30%", "Data and core, in slices", "Product teams can use clean, consented customer, payment, and credit data."),
        ("20%", "Cyber, fraud, resilience", "Controls are tested against a live scenario, not a questionnaire."),
        ("20%", "Artificial intelligence", "Three production uses publish a result: fraud, service, SME credit."),
        ("15%", "Channels and embedded distribution", "A simple product sells in the app. Two design partners are signed."),
        ("10%", "Instant and cross-border payments", "The rail a partner needs is seconds, with fraud controls in the same release."),
        ("5%", "Partners and hiring", "Integration has an owner. The squads that ship are staffed."),
    ]
    for a, b, c in caps:
        cap_rows.append([
            Paragraph(a, S["td_b"]),
            Paragraph(b, S["td"]),
            Paragraph(c, S["td"]),
        ])
    cap = Table(cap_rows, colWidths=[18 * mm, 52 * mm, 104 * mm])
    cap.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), TEAL),
        ("BACKGROUND", (0, 1), (-1, 1), white),
        ("BACKGROUND", (0, 2), (-1, 2), CREAM),
        ("BACKGROUND", (0, 3), (-1, 3), white),
        ("BACKGROUND", (0, 4), (-1, 4), CREAM),
        ("BACKGROUND", (0, 5), (-1, 5), white),
        ("BACKGROUND", (0, 6), (-1, 6), CREAM),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
    ]))
    story.append(cap)
    story.append(P(
        "The percentages apply to incremental technology capital, not to the whole expense base. They are a management choice, reviewed twice a year. They are not a benchmark from the surveys.",
        "footer_note",
    ))

    story.append(Spacer(1, 3 * mm))
    story.append(section_banner("5:00", "3  ·  Opportunities, and how to manage the risk"))
    story.append(Spacer(1, 3 * mm))
    story.append(P(
        "Five opportunities fit a bank with our license. Each can destroy value if we announce it and under-control it."
    ))
    story.append(P(
        "Embedded finance in journeys we already know: small-business software, home and vehicle purchases, and everyday commerce. We supply the account, the credit decision, and the payment. The partner supplies the audience. The risk is becoming plumbing and losing the right to set the price. The contract keeps customer visibility, a fair return of data, and an exit. Do not sign exclusivity we cannot leave. Large banks have started charging others to use consumer data. Ours is an asset."
    ))
    story.append(P(
        "Cash-flow credit for small firms and thinner-file households, using transactions we already hold. Nubank and WeBank showed that alternative data can expand credit without a branch. The risk is biased denial and a book that looks clever until the cycle turns. Use explainable models, human review above a set amount, fair-lending tests before launch, and an automatic stop when losses breach the limit."
    ))
    story.append(P(
        "Consented open finance. In Brazil, India, the United Kingdom, and Europe’s data-access debate, customers can take their data with them. Adoption is the hard part. A CGAP study found only about 27 percent would share data even for a better loan. In India, about 12 percent of smartphone users surveyed knew what an account aggregator was, and about 20 percent would share. The risk is pipes nobody trusts, or collecting more than we need. Ask for the minimum, in plain language, at the moment of a clear benefit. Measure consent by income and gender."
    ))
    story.append(P(
        "Productivity inside the bank: faster decisions, fewer repeated calls, cleaner controls. The risk is customer data in public tools, or advice we cannot defend. Approved systems only, a model inventory, human sign-off on credit and on complaints, and an audit trail."
    ))
    story.append(P(
        "Faster payments, and any tokenised-money design only where the regulator allows a pilot. Fraud speeds up with the payment, and new money brings liquidity and reputation risk. Ship real-time fraud controls in the same release. No pilot without treasury, legal, and financial crime together."
    ))
    story.append(P(
        "One rule covers all five. Each opportunity has a risk owner who can stop it, one customer metric, and a loss or conduct limit. Speed without that rule spends the trust premium."
    ))

    story.append(Spacer(1, 3 * mm))
    story.append(P("Leave-behind: opportunity and the control that sits beside it", "h2"))

    risk_header = [
        Paragraph("Opportunity", S["th"]),
        Paragraph("Why it is open", S["th"]),
        Paragraph("Risk", S["th"]),
        Paragraph("How it is managed", S["th"]),
    ]
    risks = [
        ("Embedded journeys in SME software, home, auto, and commerce",
         "DBS and Deutsche Bank already place the product at the decision.",
         "The bank becomes invisible plumbing and loses price.",
         "Customer visibility, data return, and an exit in the contract. No trapped exclusivity."),
        ("Cash-flow credit for small firms and thin files",
         "Nubank and WeBank expanded credit with transaction data.",
         "Bias, unfair price, and losses when the cycle turns.",
         "Explainable models, human review above a limit, fair-lending tests, automatic stop-loss."),
        ("Consented open finance",
         "Customers can move data in Brazil, India, the UK, and under Europe’s data-access debate.",
         "Pipes nobody uses, or collection beyond the need.",
         "Minimum data, plain language, at the moment of benefit. Track uptake by income and gender."),
        ("AI productivity in operations",
         "CEOs rank AI as a top investment; value is in cost and control.",
         "Data leakage and advice the bank cannot defend.",
         "Approved tools, model inventory, human sign-off, audit trail."),
        ("Instant payments and narrow digital-money pilots",
         "Interoperable, intelligent rails are becoming infrastructure.",
         "Faster fraud; liquidity and reputation risk on new money.",
         "Fraud controls in the same release. Treasury, legal, and financial crime approve any pilot."),
    ]
    rr = [risk_header]
    for a, b, c, d in risks:
        rr.append([
            Paragraph(a, S["td_b"]),
            Paragraph(b, S["td"]),
            Paragraph(c, S["td"]),
            Paragraph(d, S["td"]),
        ])
    rt = Table(rr, colWidths=[38 * mm, 44 * mm, 42 * mm, 50 * mm])
    rt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("BACKGROUND", (0, 1), (-1, 1), white),
        ("BACKGROUND", (0, 2), (-1, 2), CREAM),
        ("BACKGROUND", (0, 3), (-1, 3), white),
        ("BACKGROUND", (0, 4), (-1, 4), CREAM),
        ("BACKGROUND", (0, 5), (-1, 5), white),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 3),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
    ]))
    story.append(rt)

    story.append(Spacer(1, 4 * mm))
    story.append(section_banner("7:30", "4  ·  Thriving over the next three to five years"))
    story.append(Spacer(1, 3 * mm))
    story.append(P(
        "Sequence the work. Do not fund a five-year vision made of pilots."
    ))
    story.append(P(
        "In year one, lay the foundation. Make customer, payment, credit, and fraud data usable. Put three uses of artificial intelligence into production and publish the result: fraud, service assistance, and small-business credit. Test cyber controls against a real scenario. Make a simple product sellable in the app. Publish a short API catalogue and sign design partners, not a wall of logos."
    ))
    story.append(P(
        "In year two, open distribution. Launch two embedded journeys with named revenue. Run instant payments end to end. Move a visible share of simple sales to digital. Take cost out with what year one proved, and put part of the saving into controls and into colleagues who handle hard cases. Retrain branch staff as advisers. Close capacity that no longer has a customer job, and say so in public."
    ))
    story.append(P(
        "From year three to year five, hold the position. Be the default regulated partner in the journeys we chose, and the default app when a customer wants to understand money, not only move it. Most simple products should start digital. Cost to income should fall because routine work sits in software, while returns hold because we kept deposits, judgment, and the relationship. A narrow service for selected platforms should be a real revenue line, under the same risk standard as the app."
    ))
    story.append(P(
        "The operating model is what a rival cannot photocopy. DBS and ING put small teams on a customer outcome, with risk inside the team, releasing in weeks. Use that model for these six investments. Leave the rest of the bank on its current rhythm until the new one has earned the right to spread."
    ))

    story.append(Spacer(1, 3 * mm))
    story.append(P("Leave-behind: the three-year sequence", "h2"))
    seq_h = [
        Paragraph("When", S["th"]),
        Paragraph("What changes for the customer", S["th"]),
        Paragraph("What must be true inside the bank", S["th"]),
    ]
    seq = [
        ("Year 1\nFoundation",
         "A simple product can be bought in the app. Credit and fraud decisions are faster and explained.",
         "Priority data is usable. Three AI uses are in production with published results. Cyber is tested. A short API catalogue exists."),
        ("Year 2\nDistribution",
         "Two everyday journeys carry the bank’s account, credit, or payment. Instant payments are normal.",
         "Those journeys have named revenue. A visible share of simple sales is digital. Branch colleagues handle advice and complex cases."),
        ("Years 3–5\nPosition",
         "The bank is the default app for understanding money, and the default regulated partner in the chosen journeys.",
         "Most simple products start digital. Cost to income is structurally lower. A narrow platform service is a real revenue line under the same risk standard."),
    ]
    sr = [seq_h]
    for a, b, c in seq:
        sr.append([
            Paragraph(a.replace("\n", "<br/>"), S["td_b"]),
            Paragraph(b, S["td"]),
            Paragraph(c, S["td"]),
        ])
    st = Table(sr, colWidths=[28 * mm, 70 * mm, 76 * mm])
    st.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), TEAL),
        ("BACKGROUND", (0, 1), (-1, 1), white),
        ("BACKGROUND", (0, 2), (-1, 2), CREAM),
        ("BACKGROUND", (0, 3), (-1, 3), TEAL_SOFT),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(st)

    story.append(Spacer(1, 4 * mm))
    story.append(section_banner("9:20", "Close  ·  the three decisions"))
    story.append(Spacer(1, 3 * mm))
    story.append(P("I am asking for three decisions, not a vendor selection."))
    story.append(P(
        "Adopt the position: trusted digital relationship bank. Decline the super-app."
    ))
    story.append(P(
        "Adopt the six-part investment order and the capital split, reviewed every half year against customer and risk results."
    ))
    story.append(P(
        "Name one executive accountable for the three-year sequence, and give the risk committee a mandate to clear safe releases, not to revisit the strategy after the money is gone."
    ))
    story.append(P(
        "Done this way, we are not a bank that rented a FinTech story. We are the bank customers still choose when the choice is real, and the bank platforms need when money, credit, and the law are in the transaction."
    ))
    story.append(P("That is the recommendation."))

    story.append(Spacer(1, 4 * mm))
    story.append(callout(
        "What to watch twice a year",
        "Digitally active customers. Share of simple products opened without a branch. Time to a credit decision. Fraud loss against faster payments. Cost to serve. Partner-originated volume and whether the bank still sees the customer. Complaints on AI-assisted advice. Consent rates, including by income and gender. If a metric moves the wrong way for two reviews, the risk owner stops that stream.",
        fill=CREAM,
    ))

    # ----- evidence -----
    story.append(PageBreak())
    story.append(P("Evidence behind the pitch", "h1"))
    story.append(P(
        "The speech uses these cases and figures. The patterns are what transfer. The market shares and product menus do not.",
        "body_first",
    ))

    story.append(P("What other banks have already chosen", "h2"))
    ev_h = [
        Paragraph("Bank", S["th"]),
        Paragraph("Position it proved", S["th"]),
        Paragraph("Lesson for us", S["th"]),
    ]
    ev = [
        ("DBS, Singapore",
         "Incumbent rebuilt as a technology firm. Cloud, data, and artificial intelligence, plus an agile operating model. Finance sits inside property, car, travel, and small-business journeys. The public phrase is invisible banking.",
         "Culture and data come before the app. Embedded distribution can coexist with owning the product."),
        ("Nubank, Brazil",
         "A simple, lower-cost card grew into credit, savings, and investments for customers incumbents had priced poorly.",
         "Fairness and clarity are a growth strategy. Thin-file credit works only with tight risk limits."),
        ("Revolut, United Kingdom",
         "A financial super-app: cross-border payments, investing, insurance, and lifestyle features, with software speed as the advantage.",
         "Do not copy the costume. We lack the cost base. Customers notice when an incumbent is slow."),
        ("WeBank, China",
         "Branchless bank inside Tencent. Artificial intelligence and ecosystem data support micro-credit and small-business finance at very low unit cost.",
         "Distribution through a platform can be powerful. The license holder must still govern credit and conduct."),
        ("JPMorgan Chase",
         "Scale investment in proprietary technology and AI. In 2025 it also began charging for third-party access to consumer data.",
         "Industrialise inside the bank first. Treat data as an asset when others want access."),
        ("Deutsche Bank",
         "An API programme since 2015 lets partners place accounts and payments inside their own products.",
         "Open interfaces are a distribution tool for a universal bank, not a side lab."),
        ("ING",
         "Multi-year shift to small, empowered teams with compliance inside the team rather than after it.",
         "The operating model is the moat. A rival can buy the same vendor. It cannot photocopy how decisions ship."),
    ]
    er = [ev_h]
    for a, b, c in ev:
        er.append([
            Paragraph(a, S["td_b"]),
            Paragraph(b, S["td"]),
            Paragraph(c, S["td"]),
        ])
    et = Table(er, colWidths=[32 * mm, 78 * mm, 64 * mm])
    et.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, CREAM]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.5),
        ("TOPPADDING", (0, 0), (-1, -1), 3.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
    ]))
    story.append(et)

    story.append(Spacer(1, 4 * mm))
    story.append(P("Figures used in the speech", "h2"))
    fig = [
        ("83%", "Bank CEOs confident in their firm’s growth over three years, up from 78 percent a year earlier. Sector confidence rose from 66 to 81 percent. Digitalisation and connectivity was the top operational priority named, at 20 percent.",
         "KPMG, Banking and Capital Markets CEO Outlook, published January 2026 on 2025 fieldwork."),
        ("65% / 59%", "CEOs who call AI a top investment priority, and who expect agentic AI to have a significant or transformational impact.",
         "Same KPMG CEO outlook."),
        ("87%", "Financial institutions planning to invest in modernization over the next 12 months.",
         "Finastra, Financial Services State of the Nation Survey 2026, eleven markets."),
        ("54%", "Institutions that use a fintech partnership as the default route to modernization.",
         "Finastra 2026."),
        ("40%", "Projected increase in security investment in 2026 among those respondents.",
         "Finastra 2026."),
        ("29%", "Respondents who name cloud adoption as a priority, as the layer under personalization, compliance, and speed.",
         "Finastra 2026."),
        ("96 / 95 / 95", "Emphasis on online banking, mobile banking, and email or SMS banking.",
         "KPMG Banking Technology Survey 2025."),
        ("52%", "Banks citing fintech competitors as a reason to change the offer. Half also tie digital-channel investment to a more personal experience.",
         "KPMG 2025."),
        ("93 / 89 / 81", "Barriers to modernising data: privacy and risk, data quality, legacy integration.",
         "KPMG 2025."),
        ("89% / 73%", "Banks increasing the cyber budget, and banks that say they are adequately prepared for an attack.",
         "KPMG 2025."),
        ("27%", "People who, in a CGAP study, would share data even when shown a better loan or limit.",
         "Cited in BIS Paper No. 168, Opening doors to open finance, from CGAP 2023."),
        ("12% / 20% / 10%", "In an Indian CGAP survey of about 2,000 smartphone users: familiar with account aggregators, willing to share financial data, and, among loan applicants, actually using the account-aggregator route.",
         "BIS Paper No. 168, citing Salman and Fernandez Vidal, CGAP 2024."),
    ]
    fr = [[
        Paragraph("Figure", S["th"]),
        Paragraph("What it supports in the pitch", S["th"]),
        Paragraph("Source", S["th"]),
    ]]
    for a, b, c in fig:
        fr.append([
            Paragraph(a, S["td_b"]),
            Paragraph(b, S["td"]),
            Paragraph(c, S["td"]),
        ])
    ft = Table(fr, colWidths=[24 * mm, 88 * mm, 62 * mm])
    ft.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), TEAL),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, CREAM]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.3, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 3),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    story.append(ft)

    story.append(Spacer(1, 5 * mm))
    story.append(P("Sources", "h2"))
    sources = [
        "KPMG, 2026 Banking Technology Survey. kpmg.com/us/en/articles/kpmg-banking-industry-technology-survey-results.html",
        "KPMG, Banking Technology Survey 2025. Priorities across channels, generative AI, data, and cyber budgets.",
        "KPMG, 2025 Banking and Capital Markets CEO Outlook (PDF issued January 2026). Growth confidence, digitalisation, and AI investment.",
        "Finastra, Financial Services State of the Nation Survey 2026. Modernization, partnerships, security spend, and cloud.",
        "McKinsey, Global Payments Report 2025. Interoperability, AI at the payment, programmable liquidity, and regulated digital money, with a view through 2029.",
        "Bank for International Settlements, Paper No. 168, Opening doors to open finance: evidence from the international experience. Adoption gaps in Brazil and India; JPMorgan’s 2025 data-access fees; Europe’s Financial Data Access debate.",
        "Deutsche Bank API programme, described in the Journal of Digital Banking: from open banking interfaces, launched in 2015, toward embedded finance.",
        "Case pattern for DBS, Nubank, Revolut, and WeBank: incumbent reinvention, mass digital inclusion, super-app expansion, and AI-native ecosystem banking. Used here as strategic types, not as a claim that this bank should replicate any one balance sheet.",
    ]
    for s in sources:
        story.append(P("•  " + s, "src"))

    story.append(Spacer(1, 3 * mm))
    story.append(P(
        "Scope. The pitch is written for an incumbent bank with a deposit franchise, a credit book, branches, and a full license. It assumes management can fund a multi-year technology programme and can decline work that does not serve the position. The capital split is a proposal for this discussion. It should be reset to the bank’s own baseline before it is approved.",
        "footer_note",
    ))

    doc.build(story)
    print(OUT)


if __name__ == "__main__":
    build()
