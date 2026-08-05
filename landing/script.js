/* Landing behaviour: reveal on scroll, a shallow parallax on the port backdrop,
   and stopping both when the hero is off-screen. No dependencies — the page has
   to be cheap on a phone before it is anything else. */
(() => {
  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const panels = document.querySelectorAll(".reveal");

  if (still || !("IntersectionObserver" in window)) {
    panels.forEach((panel) => panel.classList.add("seen"));
    return;
  }

  const revealer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("seen");
      revealer.unobserve(entry.target);
    });
  }, { threshold: 0.15, rootMargin: "0px 0px -6%" });

  panels.forEach((panel) => revealer.observe(panel));

  const hero = document.querySelector(".hero");
  const sky = document.querySelector(".hero-sky");
  if (!hero || !sky) return;

  let onScreen = true;
  let queued = false;

  const park = new IntersectionObserver(([entry]) => {
    onScreen = entry.isIntersecting;
    hero.classList.toggle("is-parked", !onScreen);
  }, { threshold: 0 });
  park.observe(hero);

  const drawParallax = () => {
    queued = false;
    if (!onScreen) return;
    // A third of the scroll distance, snapped to whole pixels so the backdrop
    // never lands between two source pixels.
    sky.style.transform = `translateY(${Math.round(window.scrollY / 3)}px)`;
  };

  addEventListener("scroll", () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(drawParallax);
  }, { passive: true });
})();
