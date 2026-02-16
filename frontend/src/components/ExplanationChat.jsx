import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
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
            const token = localStorage.getItem('alethia_token');
            const response = await fetch(apiUrl('/chat'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`
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
        <motion.div
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            className="fixed right-0 top-0 h-screen w-[450px] bg-background border-l border-border z-[60] shadow-2xl flex flex-col"
        >
            {/* Header */}
            <header className="p-6 border-b border-border flex justify-between items-center bg-surface/30">
                <div className="flex items-center gap-3">
                    <MessageSquare size={18} className="text-primary" />
                    <div className="space-y-0.5">
                        <h3 className="text-[10px] font-mono font-bold tracking-[0.2em] uppercase text-text">Logic Clarification</h3>
                        <p className="text-[9px] text-text-dim uppercase tracking-widest flex items-center gap-1">
                            <ShieldCheck size={10} className="text-primary" />
                            Context-Aware Persona
                        </p>
                    </div>
                </div>
                <button onClick={onClose} className="p-2 hover:bg-surface rounded-lg transition-colors">
                    <X size={18} className="text-text-dim" />
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
                            max-w-[90%] p-4 rounded-xl text-xs leading-relaxed font-mono
                            ${msg.role === 'user'
                                ? 'bg-primary/10 text-primary border border-primary/20'
                                : 'bg-surface/50 text-text border border-border'}
                        `}>
                            {msg.content}
                        </div>
                        <span className="text-[9px] font-mono text-text-dim uppercase tracking-tighter opacity-40 px-1">
                            {msg.role === 'user' ? 'Consultant' : 'Aletheia Intelligence'}
                        </span>
                    </div>
                ))}
                {loading && (
                    <div className="flex flex-col gap-2 items-start animate-pulse">
                        <div className="bg-surface/50 border border-border p-4 rounded-xl w-32 h-10" />
                        <span className="text-[9px] font-mono text-text-dim uppercase tracking-tighter opacity-40">Processing...</span>
                    </div>
                )}
            </div>

            {/* Suggested Prompts */}
            {messages.length <= 2 && (
                <div className="px-6 py-3 border-t border-border/30 flex flex-wrap gap-2">
                    {prompts.map((prompt, i) => (
                        <button
                            key={i}
                            onClick={() => handleSend(prompt)}
                            disabled={loading}
                            className="px-3 py-1.5 text-[9px] font-mono uppercase tracking-wider border border-border/50 rounded-lg text-text-dim hover:text-primary hover:border-primary/30 transition-colors disabled:opacity-30"
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
            <div className="p-6 bg-surface/20">
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
                        className="w-full bg-background border border-border rounded-xl px-4 py-3 text-xs font-mono text-text placeholder:text-text-dim/40 focus:border-primary outline-none transition-all resize-none min-h-[100px]"
                    />
                    <button
                        onClick={() => handleSend()}
                        disabled={!input.trim() || loading}
                        className="absolute bottom-3 right-3 p-2 bg-primary text-black rounded-lg hover:bg-white transition-all disabled:opacity-20"
                    >
                        <Send size={16} />
                    </button>
                </div>
                <div className="mt-4 text-[8px] font-mono text-text-dim/40 uppercase tracking-[0.2em] text-center">
                    Secure Channel &bull; Zero Hallucination Mode Active
                </div>
            </div>
        </motion.div>
    );
};

export default ExplanationChat;
