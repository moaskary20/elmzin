<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Elmzin — Book chairs at salons &amp; beauty centers</title>
    <meta
      name="description"
      content="Elmzin connects customers with barbershops and beauty centers. Discover salons, choose a service, and book your chair in minutes."
    />
    <link rel="icon" href="{{ asset('img/landing/logo.png') }}" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Syne:wght@600;700;800&family=Sora:wght@400;500;600&display=swap"
      rel="stylesheet"
    />
    <style>
      :root {
        --ink: #0c0b09;
        --ink-soft: #1a1712;
        --cream: #f3eee4;
        --cream-dim: #d9d0c0;
        --gold: #d4a84b;
        --gold-deep: #a67c2a;
        --gold-glow: rgba(212, 168, 75, 0.35);
        --line: rgba(212, 168, 75, 0.22);
        --panel: rgba(26, 23, 18, 0.72);
        --ease: cubic-bezier(0.22, 1, 0.36, 1);
      }

      * {
        box-sizing: border-box;
      }

      html {
        scroll-behavior: smooth;
      }

      body {
        margin: 0;
        font-family: "Sora", sans-serif;
        color: var(--cream);
        background: var(--ink);
        line-height: 1.6;
        overflow-x: hidden;
      }

      img {
        max-width: 100%;
        display: block;
      }

      a {
        color: inherit;
        text-decoration: none;
      }

      .font-display {
        font-family: "Syne", sans-serif;
        letter-spacing: -0.03em;
      }

      .shell {
        width: min(1120px, calc(100% - 2.5rem));
        margin-inline: auto;
      }

      /* —— Nav —— */
      .nav {
        position: fixed;
        inset: 0 0 auto;
        z-index: 40;
        padding: 1.1rem 0;
        background: linear-gradient(180deg, rgba(12, 11, 9, 0.92), transparent);
        backdrop-filter: blur(8px);
      }

      .nav-inner {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
      }

      .brand {
        display: inline-flex;
        align-items: center;
        gap: 0.75rem;
      }

      .brand img {
        width: 44px;
        height: 44px;
        border-radius: 50%;
        box-shadow: 0 0 0 1px var(--line);
      }

      .brand span {
        font-family: "Syne", sans-serif;
        font-weight: 700;
        font-size: 1.2rem;
        color: var(--gold);
      }

      .nav-links {
        display: flex;
        gap: 1.4rem;
        align-items: center;
        font-size: 0.88rem;
        color: var(--cream-dim);
      }

      .nav-links a:hover {
        color: var(--gold);
      }

      .nav-cta {
        display: inline-flex;
        align-items: center;
        padding: 0.65rem 1.1rem;
        border-radius: 999px;
        background: var(--gold);
        color: var(--ink);
        font-weight: 600;
        font-size: 0.86rem;
        transition: transform 0.35s var(--ease), box-shadow 0.35s var(--ease);
      }

      .nav-cta:hover {
        transform: translateY(-2px);
        box-shadow: 0 12px 28px var(--gold-glow);
      }

      .nav-toggle {
        display: none;
        background: none;
        border: 1px solid var(--line);
        color: var(--cream);
        border-radius: 10px;
        padding: 0.5rem 0.7rem;
        cursor: pointer;
      }

      /* —— Hero —— */
      .hero {
        position: relative;
        min-height: 100svh;
        display: grid;
        align-items: end;
        isolation: isolate;
      }

      .hero-media {
        position: absolute;
        inset: 0;
        z-index: -2;
      }

      .hero-media img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        animation: heroDrift 28s ease-in-out infinite alternate;
      }

      .hero-shade {
        position: absolute;
        inset: 0;
        z-index: -1;
        background:
          linear-gradient(90deg, rgba(12, 11, 9, 0.92) 18%, rgba(12, 11, 9, 0.45) 62%, rgba(12, 11, 9, 0.7)),
          linear-gradient(0deg, rgba(12, 11, 9, 0.95) 8%, transparent 48%);
      }

      .hero-copy {
        padding: clamp(6.5rem, 14vh, 9rem) 0 4.5rem;
        max-width: 38rem;
      }

      .hero-brand {
        display: inline-flex;
        align-items: center;
        gap: 0.85rem;
        margin-bottom: 1.6rem;
        animation: rise 1s var(--ease) both;
      }

      .hero-brand img {
        width: 72px;
        height: 72px;
        border-radius: 50%;
        animation: floatSoft 5s ease-in-out infinite;
      }

      .hero-brand strong {
        font-family: "Syne", sans-serif;
        font-size: clamp(2.4rem, 6vw, 3.8rem);
        font-weight: 800;
        color: var(--gold);
        line-height: 1;
      }

      .hero h1 {
        margin: 0 0 1rem;
        font-family: "Syne", sans-serif;
        font-size: clamp(2rem, 5.2vw, 3.4rem);
        font-weight: 700;
        line-height: 1.08;
        color: var(--cream);
        animation: rise 1s 0.12s var(--ease) both;
      }

      .hero p {
        margin: 0 0 1.8rem;
        color: var(--cream-dim);
        font-size: 1.08rem;
        max-width: 34rem;
        animation: rise 1s 0.22s var(--ease) both;
      }

      .hero-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 0.85rem;
        animation: rise 1s 0.32s var(--ease) both;
      }

      .btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 0.55rem;
        min-height: 3.15rem;
        padding: 0.75rem 1.35rem;
        border-radius: 14px;
        font-weight: 600;
        font-size: 0.95rem;
        border: 1px solid transparent;
        transition: transform 0.35s var(--ease), background 0.35s var(--ease), border-color 0.35s var(--ease);
      }

      .btn-primary {
        background: var(--gold);
        color: var(--ink);
      }

      .btn-primary:hover {
        transform: translateY(-2px);
        background: #e0b65a;
      }

      .btn-ghost {
        border-color: var(--line);
        color: var(--cream);
        background: rgba(12, 11, 9, 0.35);
      }

      .btn-ghost:hover {
        border-color: var(--gold);
        color: var(--gold);
      }

      /* —— Sections —— */
      section {
        padding: clamp(4.5rem, 9vw, 7rem) 0;
      }

      .section-kicker {
        color: var(--gold);
        font-size: 0.78rem;
        font-weight: 600;
        letter-spacing: 0.16em;
        text-transform: uppercase;
        margin: 0 0 0.85rem;
      }

      .section-title {
        margin: 0 0 1rem;
        font-family: "Syne", sans-serif;
        font-size: clamp(1.9rem, 4vw, 2.8rem);
        font-weight: 700;
        line-height: 1.12;
        max-width: 18ch;
      }

      .section-lead {
        margin: 0;
        color: var(--cream-dim);
        max-width: 40rem;
        font-size: 1.05rem;
      }

      .split {
        display: grid;
        grid-template-columns: 1.05fr 0.95fr;
        gap: clamp(2rem, 5vw, 4rem);
        align-items: center;
      }

      .split-media {
        position: relative;
        border-radius: 28px;
        overflow: hidden;
        min-height: 360px;
        box-shadow: 0 30px 80px rgba(0, 0, 0, 0.45);
      }

      .split-media img {
        width: 100%;
        height: 100%;
        min-height: 360px;
        object-fit: cover;
      }

      .split-media::after {
        content: "";
        position: absolute;
        inset: 0;
        background: linear-gradient(160deg, transparent 40%, rgba(12, 11, 9, 0.55));
        pointer-events: none;
      }

      .about {
        background:
          radial-gradient(ellipse at 10% 20%, rgba(212, 168, 75, 0.1), transparent 45%),
          var(--ink);
      }

      .target {
        background:
          linear-gradient(180deg, #100e0b, #0c0b09 60%),
          var(--ink);
      }

      .target-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 1.25rem;
        margin-top: 2.5rem;
      }

      .target-item {
        padding: 1.6rem 1.4rem 1.5rem;
        border: 1px solid var(--line);
        border-radius: 22px;
        background: linear-gradient(160deg, rgba(26, 23, 18, 0.9), rgba(12, 11, 9, 0.55));
        transition: border-color 0.35s var(--ease), transform 0.35s var(--ease);
      }

      .target-item:hover {
        border-color: rgba(212, 168, 75, 0.55);
        transform: translateY(-4px);
      }

      .icon-orb {
        width: 3.1rem;
        height: 3.1rem;
        border-radius: 16px;
        display: grid;
        place-items: center;
        margin-bottom: 1.1rem;
        background: rgba(212, 168, 75, 0.12);
        color: var(--gold);
        border: 1px solid var(--line);
      }

      .icon-orb svg {
        width: 1.45rem;
        height: 1.45rem;
        fill: none;
        stroke: currentColor;
        stroke-width: 1.7;
        stroke-linecap: round;
        stroke-linejoin: round;
      }

      .target-item h3 {
        margin: 0 0 0.55rem;
        font-family: "Syne", sans-serif;
        font-size: 1.25rem;
      }

      .target-item p {
        margin: 0;
        color: var(--cream-dim);
        font-size: 0.95rem;
      }

      .categories {
        background:
          radial-gradient(ellipse at 80% 0%, rgba(212, 168, 75, 0.1), transparent 42%),
          var(--ink-soft);
      }

      .category-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 1.25rem;
        margin-top: 2.5rem;
      }

      .category-card {
        position: relative;
        border-radius: 24px;
        overflow: hidden;
        min-height: 320px;
        border: 1px solid var(--line);
        isolation: isolate;
        transition: transform 0.4s var(--ease), border-color 0.35s var(--ease);
      }

      .category-card:hover {
        transform: translateY(-5px);
        border-color: rgba(212, 168, 75, 0.55);
      }

      .category-card img {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        object-fit: cover;
        z-index: -2;
      }

      .category-card::after {
        content: "";
        position: absolute;
        inset: 0;
        z-index: -1;
        background: linear-gradient(180deg, rgba(12, 11, 9, 0.15) 20%, rgba(12, 11, 9, 0.92) 78%);
      }

      .category-card .body {
        position: absolute;
        inset: auto 0 0;
        padding: 1.4rem 1.35rem 1.5rem;
      }

      .category-card .num {
        display: inline-block;
        margin-bottom: 0.55rem;
        font-size: 0.72rem;
        font-weight: 600;
        letter-spacing: 0.14em;
        text-transform: uppercase;
        color: var(--gold);
      }

      .category-card h3 {
        margin: 0 0 0.45rem;
        font-family: "Syne", sans-serif;
        font-size: 1.45rem;
      }

      .category-card p {
        margin: 0;
        color: var(--cream-dim);
        font-size: 0.92rem;
      }

      .mission,
      .vision {
        position: relative;
      }

      .mission {
        background:
          radial-gradient(circle at 90% 10%, rgba(212, 168, 75, 0.12), transparent 35%),
          var(--ink-soft);
      }

      .vision {
        background:
          radial-gradient(circle at 0% 80%, rgba(212, 168, 75, 0.1), transparent 40%),
          var(--ink);
      }

      .quote-mark {
        font-family: "Syne", sans-serif;
        font-size: 4.5rem;
        line-height: 0.7;
        color: var(--gold);
        opacity: 0.55;
        margin-bottom: 0.6rem;
      }

      .mosaic {
        display: grid;
        grid-template-columns: 1.2fr 0.8fr;
        grid-template-rows: 1fr 1fr;
        gap: 0.85rem;
        min-height: 420px;
      }

      .mosaic figure {
        margin: 0;
        border-radius: 22px;
        overflow: hidden;
        position: relative;
      }

      .mosaic figure:first-child {
        grid-row: 1 / span 2;
      }

      .mosaic img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        min-height: 180px;
      }

      .mosaic figcaption {
        position: absolute;
        left: 1rem;
        bottom: 1rem;
        font-size: 0.8rem;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--cream);
        text-shadow: 0 2px 12px rgba(0, 0, 0, 0.65);
      }

      /* —— Download —— */
      .download {
        position: relative;
        overflow: hidden;
        background:
          linear-gradient(135deg, rgba(212, 168, 75, 0.16), transparent 45%),
          linear-gradient(180deg, #16130e, #0c0b09);
        border-block: 1px solid var(--line);
      }

      .download-inner {
        display: grid;
        grid-template-columns: 1.1fr 0.9fr;
        gap: 2.5rem;
        align-items: center;
      }

      .store-row {
        display: flex;
        flex-wrap: wrap;
        gap: 0.9rem;
        margin-top: 1.8rem;
      }

      .store-btn {
        display: inline-flex;
        align-items: center;
        gap: 0.85rem;
        min-width: 210px;
        padding: 0.85rem 1.15rem;
        border-radius: 16px;
        border: 1px solid var(--line);
        background: rgba(12, 11, 9, 0.65);
        transition: transform 0.35s var(--ease), border-color 0.35s var(--ease), background 0.35s var(--ease);
      }

      .store-btn:hover {
        transform: translateY(-3px);
        border-color: var(--gold);
        background: rgba(26, 23, 18, 0.95);
      }

      .store-btn svg,
      .store-btn img {
        width: 28px;
        height: 28px;
        flex-shrink: 0;
      }

      .store-btn small {
        display: block;
        font-size: 0.68rem;
        color: var(--cream-dim);
        text-transform: uppercase;
        letter-spacing: 0.06em;
      }

      .store-btn strong {
        display: block;
        font-size: 1.05rem;
        font-family: "Syne", sans-serif;
        margin-top: 0.1rem;
      }

      .phone-frame {
        justify-self: end;
        width: min(280px, 100%);
        aspect-ratio: 9 / 18.5;
        border-radius: 36px;
        padding: 10px;
        background: linear-gradient(160deg, #2a2418, #0c0b09);
        border: 1px solid var(--line);
        box-shadow:
          0 30px 70px rgba(0, 0, 0, 0.55),
          inset 0 0 0 1px rgba(212, 168, 75, 0.12);
        animation: floatSoft 6s ease-in-out infinite;
      }

      .phone-frame img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        border-radius: 28px;
      }

      /* —— Footer —— */
      footer {
        padding: 2.4rem 0 2.8rem;
        border-top: 1px solid var(--line);
        color: var(--cream-dim);
        font-size: 0.9rem;
      }

      .footer-inner {
        display: flex;
        flex-wrap: wrap;
        gap: 1rem;
        justify-content: space-between;
        align-items: center;
      }

      .footer-links {
        display: flex;
        gap: 1.2rem;
      }

      .footer-links a:hover {
        color: var(--gold);
      }

      /* —— Motion helpers —— */
      .reveal {
        opacity: 0;
        transform: translateY(28px);
        transition: opacity 0.8s var(--ease), transform 0.8s var(--ease);
      }

      .reveal.in {
        opacity: 1;
        transform: none;
      }

      @keyframes rise {
        from {
          opacity: 0;
          transform: translateY(24px);
        }
        to {
          opacity: 1;
          transform: none;
        }
      }

      @keyframes floatSoft {
        0%,
        100% {
          transform: translateY(0);
        }
        50% {
          transform: translateY(-8px);
        }
      }

      @keyframes heroDrift {
        from {
          transform: scale(1.04) translate3d(0, 0, 0);
        }
        to {
          transform: scale(1.1) translate3d(-1.5%, 1%, 0);
        }
      }

        @media (max-width: 900px) {
        .split,
        .download-inner,
        .target-grid,
        .category-grid {
          grid-template-columns: 1fr;
        }

        .mosaic {
          grid-template-columns: 1fr 1fr;
          grid-template-rows: auto;
          min-height: 0;
        }

        .mosaic figure:first-child {
          grid-row: auto;
          grid-column: 1 / -1;
          min-height: 240px;
        }

        .phone-frame {
          justify-self: center;
        }

        .nav-links {
          display: none;
        }

        .nav-toggle {
          display: inline-flex;
        }

        .nav.open .nav-links {
          display: flex;
          position: absolute;
          top: 100%;
          left: 1.25rem;
          right: 1.25rem;
          flex-direction: column;
          align-items: stretch;
          padding: 1rem;
          border-radius: 16px;
          background: rgba(18, 15, 11, 0.96);
          border: 1px solid var(--line);
        }
      }

      @media (max-width: 560px) {
        .shell {
          width: min(1120px, calc(100% - 1.5rem));
        }

        .hero-brand img {
          width: 58px;
          height: 58px;
        }

        .store-btn {
          width: 100%;
        }
      }

      @media (prefers-reduced-motion: reduce) {
        *,
        *::before,
        *::after {
          animation: none !important;
          transition: none !important;
        }

        .reveal {
          opacity: 1;
          transform: none;
        }
      }
    </style>
  </head>
  <body>
    <header class="nav" id="nav">
      <div class="shell nav-inner">
        <a class="brand" href="#top" aria-label="Elmzin home">
          <img src="{{ asset('img/landing/logo.png') }}" alt="Elmzin logo" />
          <span>Elmzin</span>
        </a>
        <button class="nav-toggle" type="button" id="navToggle" aria-label="Open menu">Menu</button>
        <nav class="nav-links" aria-label="Primary">
          <a href="#about">About</a>
          <a href="#categories">Categories</a>
          <a href="#target">Target</a>
          <a href="#mission">Mission</a>
          <a href="#vision">Vision</a>
          <a class="nav-cta" href="#download">Download app</a>
        </nav>
      </div>
    </header>

    <main id="top">
      <section class="hero" aria-label="Hero">
        <div class="hero-media" aria-hidden="true">
          <img
            src="{{ asset('img/landing/atmosphere.jpg') }}"
            alt=""
            width="1600"
            height="900"
          />
        </div>
        <div class="hero-shade" aria-hidden="true"></div>
        <div class="shell hero-copy">
          <div class="hero-brand">
            <img src="{{ asset('img/landing/logo.png') }}" alt="" />
            <strong>Elmzin</strong>
          </div>
          <h1>Your chair is waiting.</h1>
          <p>
            Elmzin connects customers with barbershops and beauty centers—so booking
            a cut, color, or treatment takes minutes, not phone calls.
          </p>
          <div class="hero-actions">
            <a class="btn btn-primary" href="#download">Download the app</a>
            <a class="btn btn-ghost" href="#about">Discover Elmzin</a>
          </div>
        </div>
      </section>

      <section class="about" id="about">
        <div class="shell split">
          <div class="reveal">
            <p class="section-kicker">About us</p>
            <h2 class="section-title">The bridge between guests and great chairs.</h2>
            <p class="section-lead">
              Elmzin is a booking marketplace built for grooming and beauty.
              Customers discover trusted salons nearby, compare services, and lock
              a time. The app is organized into three main categories—Men, Women,
              and Kids—so every guest finds the right chair faster. Salons and
              beauty centers receive clear bookings and grow with less front-desk
              friction.
            </p>
          </div>
          <div class="split-media reveal">
            <img
              src="{{ asset('img/landing/hero.jpg') }}"
              alt="Warm salon atmosphere with chairs ready for guests"
              width="900"
              height="700"
            />
          </div>
        </div>
      </section>

      <section class="categories" id="categories">
        <div class="shell">
          <div class="reveal">
            <p class="section-kicker">App categories</p>
            <h2 class="section-title">Three main sections inside Elmzin.</h2>
            <p class="section-lead">
              Browse by who the visit is for—then pick a salon, service, and time.
            </p>
          </div>
          <div class="category-grid">
            <article class="category-card reveal">
              <img
                src="{{ asset('img/landing/salon-men.jpg') }}"
                alt="Men’s grooming salon"
              />
              <div class="body">
                <span class="num">01 — Men</span>
                <h3>Men</h3>
                <p>Barbershops and men’s grooming—cuts, beard care, and classic chairs.</p>
              </div>
            </article>
            <article class="category-card reveal">
              <img
                src="{{ asset('img/landing/salon-women.jpg') }}"
                alt="Women’s beauty center"
              />
              <div class="body">
                <span class="num">02 — Women</span>
                <h3>Women</h3>
                <p>Beauty salons and women’s care—color, styling, makeup, and treatments.</p>
              </div>
            </article>
            <article class="category-card reveal">
              <img
                src="{{ asset('img/landing/salon-kids.jpg') }}"
                alt="Kids salon"
              />
              <div class="body">
                <span class="num">03 — Kids</span>
                <h3>Kids</h3>
                <p>Kids’ salons and gentle haircuts—friendly spaces for little guests.</p>
              </div>
            </article>
          </div>
        </div>
      </section>

      <section class="target" id="target">
        <div class="shell">
          <div class="reveal">
            <p class="section-kicker">Target</p>
            <h2 class="section-title">Built for everyone who cares about the chair.</h2>
            <p class="section-lead">
              One product, two sides of the same appointment—guests who want
              confidence, and salons that want a fuller day.
            </p>
          </div>
          <div class="target-grid">
            <article class="target-item reveal">
              <div class="icon-orb" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                  <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
              </div>
              <h3>Customers</h3>
              <p>
                Men, women, and families looking for barbershops, beauty centers,
                and kids salons—with transparent prices and real availability.
              </p>
            </article>
            <article class="target-item reveal">
              <div class="icon-orb" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
                </svg>
              </div>
              <h3>Barbershops</h3>
              <p>
                Classic and modern barber chairs that want steady walk-ups replaced
                by confirmed appointments and repeat guests.
              </p>
            </article>
            <article class="target-item reveal">
              <div class="icon-orb" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="3" />
                  <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
                </svg>
              </div>
              <h3>Beauty centers</h3>
              <p>
                Color, care, and treatment studios that need a polished booking
                flow clients already trust on their phones.
              </p>
            </article>
          </div>
        </div>
      </section>

      <section class="mission" id="mission">
        <div class="shell split">
          <div class="mosaic reveal" aria-hidden="false">
            <figure>
              <img
                src="{{ asset('img/landing/salon-men.jpg') }}"
                alt="Men’s grooming salon chair"
              />
              <figcaption>Barbershops</figcaption>
            </figure>
            <figure>
              <img
                src="{{ asset('img/landing/salon-women.jpg') }}"
                alt="Beauty center styling station"
              />
              <figcaption>Beauty</figcaption>
            </figure>
            <figure>
              <img
                src="{{ asset('img/landing/salon-kids.jpg') }}"
                alt="Kids salon atmosphere"
              />
              <figcaption>Kids</figcaption>
            </figure>
          </div>
          <div class="reveal">
            <p class="section-kicker">Mission</p>
            <div class="quote-mark" aria-hidden="true">“</div>
            <h2 class="section-title">Make every visit easy to choose and easy to keep.</h2>
            <p class="section-lead">
              Our mission is to remove the friction between wanting a service and
              sitting in the right chair—by pairing discovery, scheduling, and
              salon operations in one bilingual experience.
            </p>
          </div>
        </div>
      </section>

      <section class="vision" id="vision">
        <div class="shell split">
          <div class="reveal">
            <p class="section-kicker">Vision</p>
            <h2 class="section-title">The default way cities book beauty &amp; grooming.</h2>
            <p class="section-lead">
              We envision Elmzin as the trusted layer between neighborhoods and
              their favorite chairs—where every verified salon is bookable, every
              specialist is visible, and every guest arrives knowing the chair is
              ready.
            </p>
          </div>
          <div class="split-media reveal">
            <img
              src="{{ asset('img/landing/atmosphere.jpg') }}"
              alt="Luxury salon interior with soft gold lighting"
              width="900"
              height="700"
            />
          </div>
        </div>
      </section>

      <section class="download" id="download">
        <div class="shell download-inner">
          <div class="reveal">
            <p class="section-kicker">Download app</p>
            <h2 class="section-title">Take Elmzin with you.</h2>
            <p class="section-lead">
              Browse salons, pick a service, choose a time, and manage bookings from
              Android or iPhone—built for Arabic and English.
            </p>
            <div class="store-row">
              <a
                class="store-btn"
                href="https://play.google.com/store"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="Get Elmzin on Google Play"
              >
                <img
                  src="{{ asset('img/landing/google-play.png') }}"
                  alt=""
                  width="28"
                  height="28"
                />
                <span>
                  <small>Get it on</small>
                  <strong>Google Play</strong>
                </span>
              </a>
              <a
                class="store-btn"
                href="https://apps.apple.com/"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="Download Elmzin on the App Store"
              >
                <svg viewBox="0 0 24 24" aria-hidden="true" width="28" height="28">
                  <path
                    fill="currentColor"
                    d="M16.4 13.3c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.8-3.1.8-.6 0-1.6-.7-2.7-.7-1.4 0-2.7.8-3.4 2.1-1.5 2.5-.4 6.3 1 8.3.7 1 1.5 2.1 2.6 2.1 1 0 1.4-.7 2.7-.7s1.6.7 2.7.7 1.8-1 2.5-2c.8-1.1 1.1-2.2 1.1-2.2s-2.1-.8-2.2-3.4zM14.7 6.8c.6-.7 1-1.7.9-2.7-0.9.1-1.9.6-2.5 1.3-.6.6-1.1 1.6-.9 2.5 1 .1 1.9-.5 2.5-1.1z"
                  />
                </svg>
                <span>
                  <small>Download on the</small>
                  <strong>App Store</strong>
                </span>
              </a>
            </div>
          </div>
          <div class="phone-frame reveal" aria-hidden="true">
            <img
              src="{{ asset('img/landing/salon-women.jpg') }}"
              alt=""
            />
          </div>
        </div>
      </section>
    </main>

    <footer>
      <div class="shell footer-inner">
        <div class="brand">
          <img src="{{ asset('img/landing/logo.png') }}" alt="" width="36" height="36" style="width:36px;height:36px;border-radius:50%" />
          <span>Elmzin</span>
        </div>
        <div class="footer-links">
          <a href="{{ url('/privacy.html') }}">Privacy</a>
          <a href="{{ url('/delete.html') }}">Delete account</a>
          <a href="#download">Get the app</a>
        </div>
        <p style="margin:0">© {{ date('Y') }} Elmzin. All rights reserved.</p>
      </div>
    </footer>

    <script>
      const nav = document.getElementById("nav");
      const toggle = document.getElementById("navToggle");
      toggle?.addEventListener("click", () => {
        nav.classList.toggle("open");
      });
      nav.querySelectorAll("a").forEach((link) => {
        link.addEventListener("click", () => nav.classList.remove("open"));
      });

      const reveals = document.querySelectorAll(".reveal");
      if ("IntersectionObserver" in window) {
        const io = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                entry.target.classList.add("in");
                io.unobserve(entry.target);
              }
            });
          },
          { threshold: 0.16, rootMargin: "0px 0px -8% 0px" }
        );
        reveals.forEach((el) => io.observe(el));
      } else {
        reveals.forEach((el) => el.classList.add("in"));
      }
    </script>
  </body>
</html>
