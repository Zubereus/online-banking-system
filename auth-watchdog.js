(function () {
	const getApiBase = () =>
		window.location.origin.startsWith("http")
			? `${window.location.origin}/api`
			: "http://localhost:8080/api";

	const fetchWithTimeout = async (url, options = {}, timeoutMs = 5000) => {
		const controller = new AbortController();
		const timeoutId = window.setTimeout(() => controller.abort(), timeoutMs);

		try {
			return await fetch(url, {
				...options,
				signal: controller.signal
			});
		} finally {
			window.clearTimeout(timeoutId);
		}
	};

	const clearCustomerSession = () => {
		sessionStorage.removeItem("vcbAuthenticated");
		sessionStorage.removeItem("vcbUser");
		sessionStorage.removeItem("vcbFullName");
		sessionStorage.removeItem("vcbCCCD");
		sessionStorage.removeItem("vcbAccountNumber");
	};

	const clearAdminSession = () => {
		sessionStorage.removeItem("vcbAdminAuthenticated");
		sessionStorage.removeItem("vcbAdminToken");
		sessionStorage.removeItem("vcbAdminName");
		sessionStorage.removeItem("vcbAdminUser");
		sessionStorage.removeItem("vcbAdminCode");
		sessionStorage.removeItem("vcbAdminCccd");
		sessionStorage.removeItem("vcbAdminGender");
		sessionStorage.removeItem("vcbAdminNationality");
		sessionStorage.removeItem("vcbAdminPhones");
		sessionStorage.removeItem("vcbAdminEmails");
	};

	const start = ({ validator, onInvalid, intervalMs = 15000 } = {}) => {
		if (typeof validator !== "function" || typeof onInvalid !== "function") {
			throw new Error("VCBSessionWatchdog.start requires validator and onInvalid functions.");
		}

		let stopped = false;
		let timerId = null;

		const invalidate = () => {
			if (stopped) {
				return;
			}

			stopped = true;
			if (timerId !== null) {
				window.clearInterval(timerId);
			}
			onInvalid();
		};

		const runCheck = async () => {
			if (stopped) {
				return;
			}

			try {
				const valid = await validator();
				if (!valid) {
					invalidate();
				}
			} catch (error) {
				invalidate();
			}
		};

		void runCheck();
		timerId = window.setInterval(runCheck, intervalMs);

		return () => {
			stopped = true;
			if (timerId !== null) {
				window.clearInterval(timerId);
			}
		};
	};

	window.VCBSessionWatchdog = {
		getApiBase,
		fetchWithTimeout,
		clearCustomerSession,
		clearAdminSession,
		start
	};
})();