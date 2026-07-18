// HiroBuilds LP — interactions (vanilla JS / no dependencies)

// 1. Hero catch: 1文字ずつフェードイン（brタグは維持）
(() => {
  const catchEl = document.getElementById("heroCatch");
  if (!catchEl) return;
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduced) return;

  let delay = 0;
  const step = 0.035; // 秒/文字
  const wrapTextNodes = (node) => {
    [...node.childNodes].forEach((child) => {
      if (child.nodeType === Node.TEXT_NODE) {
        const frag = document.createDocumentFragment();
        const punct = /[、。！？!?」）)]/;
        let lastSpan = null;
        [...child.textContent].forEach((ch) => {
          // 句読点は直前の文字のspanに連結＝行頭に孤立させない（禁則処理）
          if (punct.test(ch) && lastSpan) {
            lastSpan.textContent += ch;
            return;
          }
          const span = document.createElement("span");
          span.className = "char";
          span.textContent = ch;
          span.style.animationDelay = `${delay.toFixed(3)}s`;
          delay += step;
          frag.appendChild(span);
          lastSpan = span;
        });
        node.replaceChild(frag, child);
      }
    });
  };
  wrapTextNodes(catchEl);
})();

// 2. スクロール連動の出現アニメーション
(() => {
  const targets = document.querySelectorAll(".reveal");
  if (!targets.length) return;
  if (!("IntersectionObserver" in window)) {
    targets.forEach((el) => el.classList.add("is-visible"));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          io.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.15, rootMargin: "0px 0px -40px 0px" }
  );
  targets.forEach((el) => io.observe(el));
})();

// 3. ヘッダー：スクロールで影をつける
(() => {
  const header = document.getElementById("siteHeader");
  if (!header) return;
  const onScroll = () => {
    header.classList.toggle("scrolled", window.scrollY > 10);
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
})();

// 4. デモカードのスライダー（矢印＝1カード分スクロール・端で無効化）
(() => {
  const slider = document.getElementById("worksSlider");
  const prev = document.getElementById("sliderPrev");
  const next = document.getElementById("sliderNext");
  if (!slider || !prev || !next) return;

  const cardWidth = () => {
    const card = slider.querySelector(".work-card");
    if (!card) return 320;
    const gap = parseFloat(getComputedStyle(slider).columnGap || "20");
    return card.getBoundingClientRect().width + gap;
  };

  const wrap = slider.closest(".works-slider-wrap");
  const updateArrows = () => {
    // 全カードが収まっとる幅では矢印ごと非表示（押せない飾りを出さない）
    const noOverflow = slider.scrollWidth <= slider.clientWidth + 2;
    if (wrap) wrap.classList.toggle("no-overflow", noOverflow);
    const maxScroll = slider.scrollWidth - slider.clientWidth - 2;
    prev.disabled = slider.scrollLeft <= 2;
    next.disabled = slider.scrollLeft >= maxScroll;
  };

  prev.addEventListener("click", () => slider.scrollBy({ left: -cardWidth(), behavior: "smooth" }));
  next.addEventListener("click", () => slider.scrollBy({ left: cardWidth(), behavior: "smooth" }));
  slider.addEventListener("scroll", updateArrows, { passive: true });
  window.addEventListener("resize", updateArrows, { passive: true });
  updateArrows();
})();
