'use client';

import { useState, useRef, useEffect } from 'react';
import type { Language } from '@/lib/translations';
import type { ShopData } from '@/lib/products';

interface Message {
  role: 'user' | 'ai';
  text: string;
}

interface ChatWidgetProps {
  shopId: string;
  shopData: ShopData;
  language: Language;
}

const t = {
  en: {
    title: 'AI Assistant',
    placeholder: 'Ask anything...',
    send: 'Send',
    poweredBy: 'Powered by Gemini AI',
    typing: 'Typing...',
    greeting: "Hi! I'm your shop assistant. Ask me about products, prices, delivery, or anything else!",
  },
  ml: {
    title: 'AI അസിസ്റ്റന്റ്',
    placeholder: 'എന്തും ചോദിക്കൂ...',
    send: 'അയക്കുക',
    poweredBy: 'Gemini AI ഉപയോഗിക്കുന്നു',
    typing: 'ടൈപ്പ് ചെയ്യുന്നു...',
    greeting: 'ഹലോ! ഞാൻ നിങ്ങളുടെ ഷോപ്പ് അസിസ്റ്റന്റ് ആണ്. ഉൽപ്പന്നങ്ങൾ, വില, ഡെലിവറി — എന്തും ചോദിക്കൂ!',
  },
};

export function ChatWidget({ shopId, shopData, language }: ChatWidgetProps) {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [greeted, setGreeted] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const tr = t[language];

  // Only show if AI is enabled on this shop
  const aiEnabled = (shopData as unknown as Record<string, unknown>).aiSettings
    ? ((shopData as unknown as Record<string, Record<string, unknown>>).aiSettings?.enabled !== false)
    : false;

  if (!aiEnabled) return null;

  const openChat = () => {
    setOpen(true);
    if (!greeted) {
      setMessages([{ role: 'ai', text: tr.greeting }]);
      setGreeted(true);
    }
    setTimeout(() => inputRef.current?.focus(), 100);
  };

  // eslint-disable-next-line react-hooks/rules-of-hooks
  useEffect(() => {
    if (open) bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, open]);

  const sendMessage = async () => {
    const text = input.trim();
    if (!text || loading) return;

    const userMsg: Message = { role: 'user', text };
    const newMessages = [...messages, userMsg];
    setMessages(newMessages);
    setInput('');
    setLoading(true);

    // Pass last 5 messages as history
    const history = newMessages.slice(-5).map((m) => ({ role: m.role === 'user' ? 'user' : 'model', text: m.text }));

    try {
      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ shopId, message: text, history, language }),
      });
      const data = await res.json() as { reply: string };
      setMessages((prev) => [...prev, { role: 'ai', text: data.reply }]);
    } catch {
      setMessages((prev) => [...prev, { role: 'ai', text: 'Sorry, something went wrong. Please try again.' }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      {/* Floating chat button — sits above the cart bar */}
      {!open && (
        <button
          onClick={openChat}
          className="fixed bottom-20 right-4 z-50 flex h-14 w-14 items-center justify-center rounded-full bg-primary shadow-lg transition-transform hover:scale-105 active:scale-95"
          aria-label="Chat"
        >
          <svg width="24" height="24" fill="none" viewBox="0 0 24 24" className="text-primary-foreground">
            <path fill="currentColor" d="M12 2C6.48 2 2 6.03 2 11c0 2.4.94 4.6 2.5 6.26L3 21l3.74-1.5A9.78 9.78 0 0 0 12 20c5.52 0 10-4.03 10-9S17.52 2 12 2Z"/>
          </svg>
        </button>
      )}

      {/* Chat panel */}
      {open && (
        <div className="fixed bottom-0 right-0 z-50 flex h-[70vh] w-full flex-col rounded-t-2xl bg-white shadow-2xl sm:bottom-4 sm:right-4 sm:h-[500px] sm:w-96 sm:rounded-2xl">
          {/* Header */}
          <div className="flex items-center justify-between rounded-t-2xl bg-primary px-4 py-3">
            <div className="flex items-center gap-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-white/20">
                <svg width="16" height="16" fill="white" viewBox="0 0 24 24">
                  <path d="M12 2C6.48 2 2 6.03 2 11c0 2.4.94 4.6 2.5 6.26L3 21l3.74-1.5A9.78 9.78 0 0 0 12 20c5.52 0 10-4.03 10-9S17.52 2 12 2Z"/>
                </svg>
              </div>
              <div>
                <p className="text-sm font-semibold text-primary-foreground">{tr.title}</p>
                <p className="text-[10px] text-primary-foreground/70">{shopData.shopName}</p>
              </div>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="flex h-8 w-8 items-center justify-center rounded-full text-primary-foreground/80 hover:bg-white/10"
            >
              ✕
            </button>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto p-3 space-y-3">
            {messages.map((msg, i) => (
              <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                <div
                  className={`max-w-[80%] rounded-2xl px-3 py-2 text-sm leading-relaxed ${
                    msg.role === 'user'
                      ? 'rounded-br-sm bg-primary text-primary-foreground'
                      : 'rounded-bl-sm bg-gray-100 text-gray-800'
                  }`}
                >
                  {msg.text}
                </div>
              </div>
            ))}
            {loading && (
              <div className="flex justify-start">
                <div className="rounded-2xl rounded-bl-sm bg-gray-100 px-4 py-2">
                  <span className="flex gap-1">
                    <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:0ms]" />
                    <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:150ms]" />
                    <span className="h-2 w-2 animate-bounce rounded-full bg-gray-400 [animation-delay:300ms]" />
                  </span>
                </div>
              </div>
            )}
            <div ref={bottomRef} />
          </div>

          {/* Input bar */}
          <div className="border-t border-gray-100 p-3">
            <div className="flex gap-2">
              <input
                ref={inputRef}
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
                placeholder={tr.placeholder}
                className="flex-1 rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-primary"
                disabled={loading}
              />
              <button
                onClick={sendMessage}
                disabled={loading || !input.trim()}
                className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary text-primary-foreground disabled:opacity-40"
              >
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24">
                  <path fill="currentColor" d="M2 21l21-9L2 3v7l15 2-15 2v7Z"/>
                </svg>
              </button>
            </div>
            <p className="mt-1.5 text-center text-[10px] text-gray-400">{tr.poweredBy}</p>
          </div>
        </div>
      )}
    </>
  );
}
