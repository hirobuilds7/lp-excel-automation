// HiroBuilds LP — interactions（素のJS／依存なし）
// ★2026-08-25 Linear型への作り直しで整理した。
//   - 1文字フェードインは 2026-08-12 の v2 で既に廃止済み（過剰アニメ＝AI臭方針）＝残骸を削除
//   - works の横スクロールスライダーは廃止（デモを1本ずつ大きく縦に並べる形に変えたため）
//     ★カード3並び＋矢印は「箱が並んどるだけ」に見える型そのものやった

// 1. スクロール連動の出現アニメーション
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
    { threshold: 0.12, rootMargin: "0px 0px -60px 0px" }
  );
  targets.forEach((el) => io.observe(el));
})();

// 2. ヘッダーの罫線（スクロールしたら出す）
(() => {
  const header = document.getElementById("siteHeader");
  if (!header) return;
  const onScroll = () => header.classList.toggle("scrolled", window.scrollY > 10);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
})();
