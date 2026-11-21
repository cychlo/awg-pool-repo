'use strict';
'require view';
'require form';
'require uci';
'require fs';
'require ui';

return view.extend({
	handleSaveApply: function(ev, mode) {
		return this.super(ev, mode).then(function() {
			return fs.exec('/etc/init.d/awg-pool', ['restart']);
		}).then(function() {
			window.location.reload();
		}).catch(function(e) {
			ui.addNotification(null, E('p', {}, e.message), 'danger');
		});
	},

	load: function() {
		return Promise.all([
			uci.load('awg-failover'),
			uci.load('network'),
			L.resolveDefault(fs.exec('/usr/bin/awg-pool', ['--status']), { code: -1 }),
			L.resolveDefault(fs.exec('/etc/init.d/awg-pool', ['enabled']), { code: -1 }),
			L.resolveDefault(fs.exec('/etc/init.d/awg-pool', ['running']), { code: -1 })
		]);
	},

	handleAction: function(ev) {
		var act = ev.currentTarget.getAttribute('data-act');
		return fs.exec('/etc/init.d/awg-pool', [act]).then(function(res) {
			if (res.code !== 0)
				ui.addNotification(null, E('p', {},
					_('Команда завершилась с ошибкой: ') + (res.stderr || res.code)), 'danger');
			else
				ui.addNotification(null, E('p', {}, _('Выполнено: ') + act), 'info');
			window.location.reload();
		}).catch(function(e) {
			ui.addNotification(null, E('p', {}, e.message), 'danger');
		});
	},

	render: function(data) {
		var st = data[2] || {}, en = data[3] || {}, rn = data[4] || {};
		var running = (rn.code === 0), enabled = (en.code === 0);
		var btn = ui.createHandlerFn(this, 'handleAction');

		var ifaces = [];
		uci.sections('network', 'interface').forEach(function(s) {
			if (s.proto === 'amneziawg' || s.proto === 'wireguard')
				ifaces.push(s['.name']);
		});
		ifaces.sort();

		var head = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, 'AWG Failover'),
			E('div', { 'class': 'cbi-map-descr' },
				_('Пул AWG-интерфейсов: подбор страны по доступности и реальной скорости. Конфигурацию Forkop скрипт не изменяет.')),
			E('div', { 'class': 'cbi-section' }, [
				E('p', {}, [
					E('strong', {}, _('Служба: ')),
					running ? E('span', { 'style': 'color:green' }, _('работает'))
					        : E('span', { 'style': 'color:red' }, _('остановлена')),
					'   ·   ',
					E('strong', {}, _('Автозапуск: ')),
					enabled ? _('включён') : _('выключен')
				]),
				E('div', {}, [
					E('button', { 'class': 'btn cbi-button cbi-button-apply',
					  'data-act': 'start', 'click': btn }, _('Запустить')), ' ',
					E('button', { 'class': 'btn cbi-button cbi-button-reset',
					  'data-act': 'stop', 'click': btn }, _('Остановить')), ' ',
					E('button', { 'class': 'btn cbi-button cbi-button-action',
					  'data-act': 'restart', 'click': btn }, _('Перезапустить')), ' ',
					E('button', { 'class': 'btn cbi-button cbi-button-neutral',
					  'data-act': 'enable', 'click': btn }, _('Автозапуск вкл')), ' ',
					E('button', { 'class': 'btn cbi-button cbi-button-neutral',
					  'data-act': 'disable', 'click': btn }, _('Автозапуск выкл'))
				]),
				E('pre', { 'style': 'margin-top:1em;max-height:22em;overflow:auto' },
					st.stdout || _('Нет вывода. Проверьте, что /usr/bin/awg-pool установлен и исполняем.'))
			])
		]);

		var m = new form.Map('awg-failover', _('Настройки демона'));

		var s = m.section(form.NamedSection, 'main', _('Параметры проверок и таймингов'),
			_('Пустое поле = значение по умолчанию из скрипта. Save & Apply перезапускает службу.'));
		s.anonymous = true;
		s.addremove = false;

		function num(name, title, ph, min, max, descr) {
			var o = s.option(form.Value, name, title, descr || '');
			o.placeholder = String(ph);
			o.datatype = 'range(' + min + ',' + max + ')';
			o.optional = true;
			o.rmempty = true;
			return o;
		}

		num('check_interval', _('Интервал проверки, с'), 20, 5, 3600,
		    _('Период дешёвой HTTPS-проверки рабочего интерфейса. Минимум 5.'));
		num('fail_threshold', _('Неудач до перебора'), 3, 1, 20,
		    _('Время обнаружения ≈ интервал × это число.'));
		num('health_timeout', _('Таймаут HTTPS, с'), 5, 1, 60);
		num('health_tries', _('Попыток HTTPS после подъёма'), 3, 1, 10);
		num('health_retry', _('Пауза между попытками, с'), 2, 0, 60);

		var hu = s.option(form.Value, 'health_urls', _('URL проверки доступности'),
			_('Через пробел. Успех, если любой вернул 200 или 204. Держите адреса на IP, чтобы не зависеть от DNS внутри туннеля.'));
		hu.placeholder = 'https://1.1.1.1/cdn-cgi/trace https://8.8.8.8/resolve?name=example.com&type=A';
		hu.optional = true; hu.rmempty = true;

		num('min_speed_kbps', _('Порог скорости, КБ/с'), 200, 1, 1000000,
		    _('КилоБАЙТЫ в секунду: 200 ≈ 1.6 Мбит/с, 2500 ≈ 20 Мбит/с. Не ставьте выше реальной скорости канала.'));
		num('speed_every', _('Замер скорости раз в N циклов'), 30, 0, 10000,
		    _('0 = мерить только при подборе страны.'));
		num('speed_bytes', _('Объём теста, байт'), 2000000, 100000, 50000000);
		num('speed_window', _('Окно замера, с'), 8, 2, 120,
		    _('Обрыв по окну не считается отказом — скорость всё равно вычисляется.'));

		var sh = s.option(form.Value, 'speed_host', _('Хост для замера скорости'),
			_('Путь /__down?bytes= зашит в скрипт и специфичен для Cloudflare. Произвольный хост подставлять нельзя.'));
		sh.placeholder = 'speed.cloudflare.com';
		sh.datatype = 'hostname';
		sh.optional = true; sh.rmempty = true;

		num('sweep_cooldown', _('Пауза между переборами, с'), 90, 0, 86400,
		    _('Защищает рабочий интерфейс от «дёрганья». На резервы не действует.'));
		num('dead_ttl', _('Cooldown отказавшей страны, с'), 600, 0, 86400);
		num('standby_every', _('Проверка резерва раз в N циклов'), 15, 0, 10000,
		    _('0 = выключить обслуживание резервов. Работает при ≥2 интерфейсах в пуле.'));
		num('max_tries', _('Стран за один перебор, максимум'), 4, 1, 50);
		num('probe_check_every', _('Проверка маршрутов раз в N циклов'), 5, 1, 100,
		    _('Больше значение — меньше нагрузка на CPU. Маршруты пересоздаются сразу после подъёма интерфейса.'));
		num('wan_refresh_every', _('Обновление WAN-устройства раз в N циклов'), 15, 1, 1000);

		var p = m.section(form.TypedSection, 'pool', _('Интерфейсы пула'),
			_('Количество секций = количество занятых AWG-слотов. Порядок = приоритет: первая — рабочий интерфейс, остальные — резервы. В группу Fallback в Forkop добавляйте в том же порядке.'));
		p.addremove = true;
		p.anonymous = true;
		p.sortable = true;

		var pi = p.option(form.ListValue, 'iface', _('Интерфейс'));
		ifaces.forEach(function(n) { pi.value(n); });
		pi.optional = false;
		if (!ifaces.length)
			pi.description = _('AWG-интерфейсы не найдены. Создайте их в Сеть → Интерфейсы с протоколом AmneziaWG VPN.');

		var v = m.section(form.TypedSection, 'server', _('Страны / серверы'),
			_('Минимум две. Скрипт не даст членам пула сесть на одну страну. Добавление стран не увеличивает число слотов.'));
		v.addremove = true;
		v.anonymous = true;
		v.sortable = true;

		var vl = v.option(form.Value, 'label', _('Название'));
		vl.optional = true; vl.placeholder = 'Italy';

		var vh = v.option(form.Value, 'host', _('Endpoint'));
		vh.datatype = 'hostname';
		vh.optional = false;
		vh.placeholder = 'it.gw.example.com';

		var vp = v.option(form.Value, 'port', _('Порт'));
		vp.datatype = 'port';
		vp.optional = true;
		vp.placeholder = '443';

		return m.render().then(function(mapNode) {
			return E('div', {}, [ head, mapNode ]);
		});
	}
});