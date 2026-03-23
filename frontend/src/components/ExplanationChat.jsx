import React, { useState, useRef, useEffect } from 'react';
import { MessageSquare, Send, X, ShieldCheck, AlertCircle } from 'lucide-react';
import { apiUrl } from '../config/api';

const SUGGESTED_PROMPTS = {
    engine: [
        'What COBOL constructs can you analyze?',
        'How do I format my code for best results?',
        'What is the max file size?',
    ],
    result: [
        'Explain this finding in plain English',
        'Why is this flagged as CRITICAL?',
        'How should I fix this in production?',
        'Break down the decimal precision rules',
    ],
    vault: [
        'Compare these two analyses',
        'Summarize all CRITICAL findings',
        'What patterns appear across conversions?',
    ],
};

const ExplanationChat = ({ cobolContext, pythonContext, onClose, context = 'result' }) => {
    const [messages, setMessages] = useState([
        { role: 'assistant', content: 'Logical context established. I can clarify COBOL semantics or provide technical rationale for the modernization.' }
    ]);
    const [input, setInput] = useState('');
    const [loading, setLoading] = useState(false);
    const scrollRef = useRef(null);

    const prompts = SUGGESTED_PROMPTS[context] || SUGGESTED_PROMPTS.result;

    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
    }, [messages]);

    const handleSend = async (text) => {
        const query = text || input;
        if (!query.trim() || loading) return;

        const userMsg = { role: 'user', content: query };
        setMessages(prev => [...prev, userMsg]);
        setInput('');
        setLoading(true);

        try {
            const response = await fetch(apiUrl('/chat'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    cobol_context: cobolContext,
                    python_context: pythonContext,
                    user_query: query,
                    history: messages.slice(-4)
                })
            });

            if (response.ok) {
                const data = await response.json();
                setMessages(prev => [...prev, { role: 'assistant', content: data.answer }]);
            } else {
                throw new Error('Chat synchronization error');
            }
        } catch (err) {
            setMessages(prev => [...prev, {
                role: 'assistant',
                content: 'I am currently unable to provide a secure explanation. System integrity check in progress.'
            }]);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div
            className="fixed right-0 top-0 h-screen w-[450px] bg-white border-l border-[#E5E7EB] z-[60] shadow-2xl flex flex-col fade-in"
        >
            {/* Header */}
            <header className="p-6 border-b border-[#E5E7EB] flex justify-between items-center bg-[#F8F9FA]">
                <div className="flex items-center gap-3">
                    <MessageSquare size={18} className="text-[#1B2A4A]" />
                    <div className="space-y-0.5">
                        <h3 className="text-[11px] font-medium tracking-[0.2em] uppercase text-[#1A1A2E]">Logic Clarification</h3>
                        <p className="text-[9px] text-[#6B7280] uppercase tracking-widest flex items-center gap-1">
                            <ShieldCheck size={10} className="text-[#1B2A4A]" />
                            Context-Aware Persona
                        </p>
                    </div>
                </div>
                <button onClick={onClose} className="p-2 hover:bg-[#F8F9FA]  transition-colors">
                    <X size={18} className="text-[#6B7280]" />
                </button>
            </header>

            {/* Messages */}
            <div
                ref={scrollRef}
                className="flex-1 overflow-y-auto p-6 space-y-8 scroll-smooth"
            >
                {messages.map((msg, i) => (
                    <div key={i} className={`flex flex-col gap-2 ${msg.role === 'user' ? 'items-end' : 'items-start'}`}>
                        <div className={`
                            max-w-[90%] p-4  text-xs leading-relaxed font-mono
                            ${msg.role === 'user'
                                ? 'bg-[#1B2A4A]/10 text-[#1B2A4A] border border-[#1B2A4A]/20'
                                : 'bg-[#F8F9FA] text-[#1A1A2E] border border-[#E5E7EB]'}
                        `}>
                            {msg.content}
                        </div>
                        <span className="text-[9px] font-mono text-[#6B7280] uppercase tracking-tighter opacity-40 px-1">
                            {msg.role === 'user' ? 'Consultant' : 'Aletheia Intelligence'}
                        </span>
                    </div>
                ))}
                {loading && (
                    <div className="flex flex-col gap-2 items-start animate-pulse">
                        <div className="bg-[#F8F9FA] border border-[#E5E7EB] p-4  w-32 h-10" />
                        <span className="text-[9px] font-mono text-[#6B7280] uppercase tracking-tighter opacity-40">Processing...</span>
                    </div>
                )}
            </div>

            {/* Suggested Prompts */}
            {messages.length <= 2 && (
                <div className="px-6 py-3 border-t border-[#E5E7EB] flex flex-wrap gap-2">
                    {prompts.map((prompt, i) => (
                        <button
                            key={i}
                            onClick={() => handleSend(prompt)}
                            disabled={loading}
                            className="px-3 py-1.5 text-[9px] font-mono uppercase tracking-wider border border-[#E5E7EB]  text-[#6B7280] hover:text-[#1B2A4A] hover:border-[#1B2A4A]/30 transition-colors disabled:opacity-30"
                        >
                            {prompt}
                        </button>
                    ))}
                </div>
            )}

            {/* Guardrail Warning */}
            <div className="px-6 py-2 bg-amber-500/5 border-t border-b border-amber-500/10 flex items-center gap-3">
                <AlertCircle size={14} className="text-amber-500 flex-shrink-0" />
                <p className="text-[9px] font-mono leading-tight text-amber-500/80 uppercase">
                    Explanations are technical assessments only. Do not rely for external policy decisions.
                </p>
            </div>

            {/* Input */}
            <div className="p-6 bg-[#F8F9FA]">
                <div className="relative">
                    <textarea
                        value={input}
                        onChange={(e) => setInput(e.target.value)}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter' && !e.shiftKey) {
                                e.preventDefault();
                                handleSend();
                            }
                        }}
                        placeholder="Ask about specific COBOL rules..."
                        className="w-full bg-white border border-[#E5E7EB]  px-4 py-3 text-xs font-mono text-[#1A1A2E] placeholder:text-[#6B7280]/40 focus:border-[#1B2A4A] outline-none transition-all resize-none min-h-[100px]"
                    />
                    <button
                        onClick={() => handleSend()}
                        disabled={!input.trim() || loading}
                        className="absolute bottom-3 right-3 p-2 bg-[#1B2A4A] text-white hover:bg-[#243656] transition-all disabled:opacity-20"
                    >
                        <Send size={16} />
                    </button>
                </div>
                <div className="mt-4 text-[8px] font-mono text-[#6B7280]/40 uppercase tracking-[0.2em] text-center">
                    Secure Channel
                </div>
            </div>
        </div>
    );
};

export default ExplanationChat;
