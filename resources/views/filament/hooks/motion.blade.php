<div class="mz-nav-progress" aria-hidden="true"></div>
<script>
    (() => {
        const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        const replay = (selector, className) => {
            document.querySelectorAll(selector).forEach((node) => {
                node.classList.remove(className);
                void node.offsetWidth;
                node.classList.add(className);
            });
        };

        const countUp = () => {
            if (reduce) {
                return;
            }

            document.querySelectorAll('.fi-wi-stats-overview-stat-value').forEach((node) => {
                const raw = (node.textContent || '').trim();
                if (!/^\d+$/.test(raw) || node.dataset.mzCounted === raw) {
                    return;
                }

                const target = Number(raw);
                node.dataset.mzCounted = raw;
                const start = performance.now();
                const duration = 700;

                const tick = (now) => {
                    const progress = Math.min((now - start) / duration, 1);
                    const eased = 1 - Math.pow(1 - progress, 3);
                    node.textContent = String(Math.round(target * eased));
                    if (progress < 1) {
                        requestAnimationFrame(tick);
                    }
                };

                node.textContent = '0';
                requestAnimationFrame(tick);
            });
        };

        const boot = () => {
            replay('.fi-main', 'mz-page-in');
            countUp();
        };

        document.addEventListener('livewire:navigating', () => {
            document.querySelector('.mz-nav-progress')?.classList.add('is-active');
        });

        document.addEventListener('livewire:navigated', () => {
            document.querySelector('.mz-nav-progress')?.classList.remove('is-active');
            boot();
        });

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', boot);
        } else {
            boot();
        }
    })();
</script>
