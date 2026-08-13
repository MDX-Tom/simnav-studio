import Foundation

/// Scripts shared by the Apple WKWebView and Local Web Chromium adapters.
/// Keeping DOM extraction here prevents the two transports from drifting.
public enum FR24BrowserScripts {
    public static let pageText = #"""
    document.body
      ? (document.body.innerText || document.body.textContent || "")
      : (document.documentElement
          ? (document.documentElement.innerText || document.documentElement.textContent || "")
          : "")
    """#

    public static let flightHistoryExtraction = #"""
    (() => {
      const clean = (value) => String(value || "").replace(/\s+/g, " ").trim();
      const hrefValue = (anchor) => anchor.href || anchor.getAttribute("href") || "";
      const linksFor = (node) => Array.from(node.querySelectorAll("a"))
        .map((anchor) => ({
          text: clean(anchor.textContent),
          title: clean(anchor.getAttribute("title") || anchor.getAttribute("aria-label") || ""),
          href: hrefValue(anchor),
        }))
        .filter((item) => item.href || item.text || item.title);
      const cellsFor = (node) => {
        const direct = Array.from(node.querySelectorAll(":scope > td, :scope > th, :scope > [role='cell'], :scope > [role='gridcell'], :scope > [role='columnheader']"));
        const nested = direct.length ? direct : Array.from(node.querySelectorAll("td, th, [role='cell'], [role='gridcell'], [role='columnheader'], [class*='cell'], [class*='Cell']"));
        return nested
          .map((cell) => clean(cell.innerText || cell.textContent || ""))
          .filter(Boolean);
      };
      const headersFor = (node) => {
        const table = node.closest("table, [role='table'], [role='grid']");
        return Array.from(table?.querySelectorAll("thead th, thead [role='columnheader'], [role='rowgroup']:first-child [role='columnheader']") || [])
          .map((cell) => clean(cell.innerText || cell.textContent || ""))
          .filter(Boolean);
      };
      const rows = [];
      const seen = new Set();
      const collectRows = (nodes) => {
        for (const node of nodes) {
          const text = clean(node.innerText || node.textContent || "");
          if (text.length < 18 || text.length > 1800) {
            continue;
          }
          const hrefs = linksFor(node);
          const dateMatch = text.match(/\b\d{1,2}\s+[A-Za-z]{3}\s+20\d{2}\b/);
          const hasFlightStatus = /\b(STD|ATD|STA|ETA|Landed|Scheduled|Cancelled|Canceled|Diverted|Unknown|KML|CSV|Play)\b/i.test(text);
          const instanceLink = hrefs.find((link) => /(?:flightId=|\/flight\/|\/data\/flights\/[^/#?\s]+#[0-9a-f]{6,12}\b)/i.test(link.href));
          if (!dateMatch || (!hasFlightStatus && !instanceLink)) {
            continue;
          }
          const instanceKey = instanceLink?.href.match(/(?:flightId=|#)([0-9a-f]{6,12})\b/i)?.[1] || "";
          const key = `${dateMatch[0]}|${instanceKey}|${text}`;
          if (seen.has(key)) {
            continue;
          }
          seen.add(key);
          rows.push({ text, hrefs, cells: cellsFor(node), headers: headersFor(node) });
          if (rows.length >= 160) {
            break;
          }
        }
      };
      const tableRows = Array.from(document.querySelectorAll("table tbody tr, table [role='row'], [role='table'] [role='row'], [role='grid'] [role='row']"));
      collectRows(tableRows);
      if (!rows.length) {
        const fallbackRows = Array.from(document.querySelectorAll("tr, [role='row'], li, article, [class*='flight'], [class*='history'], [class*='row']"))
          .filter((node) => !node.querySelector("tr, [role='row']"));
        collectRows(fallbackRows);
      }
      const links = Array.from(document.querySelectorAll("a"))
        .map((anchor) => ({
          text: clean(anchor.textContent),
          title: clean(anchor.getAttribute("title") || anchor.getAttribute("aria-label") || ""),
          href: hrefValue(anchor),
          rowText: clean((anchor.closest("tr, [role='row'], li, article, [class*='flight'], [class*='history'], [class*='row']") || anchor.parentElement || anchor).innerText || ""),
        }))
        .filter((item) => item.href || item.text || item.title)
        .slice(0, 240);
      return JSON.stringify({
        title: clean(document.title),
        url: window.location.href,
        bodyText: clean(document.body ? document.body.innerText : ""),
        rows,
        links,
      });
    })()
    """#
}
