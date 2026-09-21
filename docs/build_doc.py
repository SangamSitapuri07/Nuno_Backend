#!/usr/bin/env python3
"""Builds the Nuno project document as a PDF.

Everything in CONTENT was read out of this repository rather than recalled,
so the numbers in the document and the numbers in the code agree.
"""
import os
import re
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table,
    TableStyle, KeepTogether, PageBreak,
)

OUT = os.path.join(os.path.dirname(__file__), 'Nuno_Project_Explained.pdf')

INK = colors.HexColor('#1a1a2e')
ACCENT = colors.HexColor('#5b3fa8')
MUTED = colors.HexColor('#5a5a72')
RULE = colors.HexColor('#d8d8e4')
CODEBG = colors.HexColor('#f4f4f8')
BANDBG = colors.HexColor('#ece8f7')

styles = getSampleStyleSheet()


def S(name, **kw):
    kw.setdefault('parent', styles['BodyText'])
    return ParagraphStyle(name, **kw)


H1 = S('H1', fontName='Helvetica-Bold', fontSize=19, leading=23,
       textColor=INK, spaceBefore=2, spaceAfter=9)
H2 = S('H2', fontName='Helvetica-Bold', fontSize=13.5, leading=17,
       textColor=ACCENT, spaceBefore=15, spaceAfter=6)
H3 = S('H3', fontName='Helvetica-Bold', fontSize=11, leading=14,
       textColor=INK, spaceBefore=10, spaceAfter=4)
BODY = S('Body', fontName='Helvetica', fontSize=9.6, leading=14.2,
         textColor=INK, alignment=TA_LEFT, spaceAfter=6)
SMALL = S('Small', fontName='Helvetica', fontSize=8.6, leading=12.4,
          textColor=MUTED, spaceAfter=5)
BULLET = S('Bullet', parent=BODY, leftIndent=11, bulletIndent=2,
           spaceAfter=3.5)
CODE = S('Code', fontName='Courier', fontSize=8.3, leading=11.6,
         textColor=INK, backColor=CODEBG, borderPadding=6,
         leftIndent=3, spaceBefore=3, spaceAfter=7)
QA = S('QA', parent=BODY, leftIndent=11, textColor=INK, spaceAfter=7)
CELL = S('Cell', fontName='Helvetica', fontSize=8.6, leading=11.8,
         textColor=INK)
CELLB = S('CellB', parent=CELL, fontName='Helvetica-Bold')


def esc(t):
    return (t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))


def rich(t):
    """`code` -> monospace, **bold** -> bold."""
    t = esc(t)
    t = re.sub(r'`([^`]+)`',
               r'<font face="Courier" size="8.8">\1</font>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', t)
    return t


def table(rows, widths, header=True):
    data = [[Paragraph(rich(c), CELLB if (header and i == 0) else CELL)
             for c in row] for i, row in enumerate(rows)]
    t = Table(data, colWidths=widths, hAlign='LEFT')
    style = [
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 4.5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4.5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('LINEBELOW', (0, 0), (-1, -2), 0.4, RULE),
        ('BOX', (0, 0), (-1, -1), 0.5, RULE),
    ]
    if header:
        style += [('BACKGROUND', (0, 0), (-1, 0), BANDBG),
                  ('LINEBELOW', (0, 0), (-1, 0), 0.7, ACCENT)]
    t.setStyle(TableStyle(style))
    return t


# ─────────────────────────────────────────────────────────────────
# CONTENT
# ─────────────────────────────────────────────────────────────────

W = 170 * mm

story = []


def h1(t): story.append(Paragraph(esc(t), H1))
def h2(t): story.append(Paragraph(esc(t), H2))
def h3(t): story.append(Paragraph(esc(t), H3))
def p(t): story.append(Paragraph(rich(t), BODY))
def small(t): story.append(Paragraph(rich(t), SMALL))
def code(t):
    # EVERY space becomes non-breaking, not just the leading ones.
    #
    # Runs of spaces collapse in HTML-ish markup wherever they appear, so
    # padding an ASCII diagram in the middle of a line was lost and the
    # columns did not line up. Courier is monospaced, so once the spaces
    # survive the alignment is exact.
    lines = [esc(line).replace(' ', '&#160;') for line in t.split('\n')]
    story.append(Paragraph('<br/>'.join(lines), CODE))
def gap(h=4): story.append(Spacer(1, h))


def bullets(items):
    for it in items:
        story.append(Paragraph(rich(it), BULLET, bulletText='\u2022'))
    gap(3)


def qa(q, a):
    story.append(KeepTogether([
        Paragraph('<b>Q. ' + esc(q) + '</b>', QA),
        Paragraph(rich(a), QA),
    ]))


import _content

_content.build({
    'h1': h1, 'h2': h2, 'h3': h3, 'p': p, 'small': small, 'code': code,
    'gap': gap, 'bullets': bullets, 'qa': qa, 'table': table,
    'story': story, 'W': W, 'mm': mm,
    'Paragraph': Paragraph, 'SMALL': SMALL, 'PageBreak': PageBreak,
})


# ─────────────────────────────────────────────────────────────────
def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 7.6)
    canvas.setFillColor(MUTED)
    canvas.drawString(20 * mm, 12 * mm, 'Nuno — Project Documentation')
    canvas.drawRightString(A4[0] - 20 * mm, 12 * mm, f'Page {doc.page}')
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(20 * mm, 15 * mm, A4[0] - 20 * mm, 15 * mm)
    canvas.restoreState()


doc = BaseDocTemplate(
    OUT, pagesize=A4,
    leftMargin=20 * mm, rightMargin=20 * mm,
    topMargin=18 * mm, bottomMargin=20 * mm,
    title='Nuno - Project Documentation',
    author='Project documentation',
)
frame = Frame(doc.leftMargin, doc.bottomMargin, W,
              A4[1] - doc.topMargin - doc.bottomMargin, id='body')
doc.addPageTemplates([PageTemplate(id='all', frames=[frame], onPage=footer)])
doc.build(story)

print(f'wrote {OUT} ({os.path.getsize(OUT):,} bytes)')
