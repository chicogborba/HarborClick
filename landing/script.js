/* Landing behaviour: reveal on scroll, layered parallax on the hero, a small
   pointer sway on desktop, and stopping all three when the hero is off-screen.
   No dependencies — the page has to be cheap on a phone before it is anything
   else, and every value it writes is a whole pixel, because a backdrop landing
   between two source pixels is a backdrop that shimmers. */
(() => {
  "use strict";

  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
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
  }, { threshold: 0.12, rootMargin: "0px 0px -6%" });

  panels.forEach((panel) => revealer.observe(panel));

  const hero = document.querySelector(".hero");
  if (!hero) return;

  const root = document.documentElement.style;
  let onScreen = true;
  let queued = false;
  let sway = 0;

  const park = new IntersectionObserver(([entry]) => {
    onScreen = entry.isIntersecting;
    hero.classList.toggle("is-parked", !onScreen);
  }, { threshold: 0 });
  park.observe(hero);

  // The backdrop, the skyline and the water are three distances, so they move
  // at three rates. The skyline is the nearest of the three and therefore the
  // fastest; without it the two remaining layers read as one flat picture.
  const draw = () => {
    queued = false;
    if (!onScreen) return;
    const y = scrollY;
    root.setProperty("--sky-y", `${Math.round(y / 3)}px`);
    root.setProperty("--skyline-y", `${Math.round(y / 1.7)}px`);
    root.setProperty("--sway", `${sway}px`);
  };

  const schedule = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(draw);
  };

  addEventListener("scroll", schedule, { passive: true });

  // A few pixels of drift under the pointer. Only where there is a real
  // pointer: on a touch screen this would either never fire or fire on a tap.
  if (matchMedia("(hover: hover) and (pointer: fine)").matches) {
    addEventListener("pointermove", (event) => {
      const next = Math.round((event.clientX / innerWidth - 0.5) * -8);
      if (next === sway) return;
      sway = next;
      schedule();
    }, { passive: true });
  }

  draw();
})();
