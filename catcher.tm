// ==UserScript==
// @name         Send Page Data with Indicator (Alt+G / Ctrl+B)
// @namespace    http://tampermonkey.net/
// @version      5.0
// @description  Alt+G – текст из body; Ctrl+B – HTML body без script. Индикатор состояния (красный/зелёный).
// @author       YourName
// @match        *://*/*
// @grant        GM_xmlhttpRequest
// @grant        GM_notification
// ==/UserScript==

(function() {
    'use strict';

    // ==================== ИНДИКАТОР СОСТОЯНИЯ ====================
    const indicator = document.createElement('div');
    indicator.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 5px;
        height: 5px;
        background-color: red;
        z-index: 999999;
        pointer-events: none;
        transition: background-color 0.2s;
    `;
    document.documentElement.appendChild(indicator);

    let isSent = false;

    function setIndicatorColor(color) {
        indicator.style.backgroundColor = color;
    }

    function markAsSent() {
        isSent = true;
        setIndicatorColor('green');
    }

    function markAsChanged() {
        if (isSent) {
            isSent = false;
            setIndicatorColor('red');
        }
    }

    // ==================== НАБЛЮДЕНИЕ ЗА ИЗМЕНЕНИЯМИ В BODY ====================
    function startObserving() {
        if (!document.body) return;
        const observer = new MutationObserver(function() {
            // Любое изменение внутри body → сброс статуса
            markAsChanged();
        });
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            characterData: true
        });
    }

    if (document.body) {
        startObserving();
    } else {
        document.addEventListener('DOMContentLoaded', startObserving);
    }

    // ==================== ОТПРАВКА ДАННЫХ ====================
    function sendPageData(payload, contentType) {
        const jsonPayload = JSON.stringify(payload);

        GM_xmlhttpRequest({
            method: 'POST',
            url: 'http://192.168.0.102:4545/putrawpage',
            headers: {
                'Content-Type': 'application/json'
            },
            data: jsonPayload,
            onload: function(response) {
                if (response.status >= 200 && response.status < 300) {
                    console.log('✅ Данные отправлены. Статус:', response.status);
                    markAsSent();
                    GM_notification({
                        text: `Тип: ${contentType}, статус: ${response.status}`,
                        title: '✅ Отправка успешна',
                        timeout: 3000
                    });
                } else {
                    console.error('❌ Сервер вернул ошибку:', response.status);
                    GM_notification({
                        text: `Ошибка ${response.status} при отправке ${contentType}`,
                        title: '❌ Ошибка отправки',
                        timeout: 5000
                    });
                }
            },
            onerror: function(err) {
                console.error('❌ Ошибка соединения:', err);
                GM_notification({
                    text: `Не удалось отправить ${contentType}. Проверьте сервер.`,
                    title: '❌ Ошибка сети',
                    timeout: 5000
                });
            }
        });
    }

    // ==================== ОБРАБОТЧИКИ КЛАВИШ ====================
    document.addEventListener('keydown', function(event) {
        // ---- Alt+G: отправка текста из body ----
        if (event.altKey && event.key === 'g') {
            event.preventDefault();
            event.stopPropagation();

            const url = window.location.href;
            const pageText = document.body ? document.body.innerText : '';

            const payload = {
                agent_id: "Real Chrome",
                url: url,
                raw_page_text: pageText,
                content_type: "text"
            };

            sendPageData(payload, 'text');
            console.log('🔹 Отправлен ТЕКСТ страницы (из body)');
        }

        // ---- Ctrl+B: отправка HTML body без script ----
        if (event.altKey && event.key === 'b') {
            event.preventDefault();
            event.stopPropagation();

            const url = window.location.href;
            if (!document.body) {
                GM_notification({
                    text: 'Тело страницы отсутствует',
                    title: '⚠️ Ошибка',
                    timeout: 3000
                });
                return;
            }
            const clonedBody = document.body.cloneNode(true);
            const scripts = clonedBody.querySelectorAll('script');
            scripts.forEach(script => script.remove());
            const bodyHtml = clonedBody.innerHTML;

            const payload = {
                agent_id: "Real Chrome",
                url: url,
                raw_page_text: bodyHtml,
                content_type: "html"
            };

            sendPageData(payload, 'html');
            console.log('🔹 Отправлен HTML body (без script)');
        }
    });
})();
