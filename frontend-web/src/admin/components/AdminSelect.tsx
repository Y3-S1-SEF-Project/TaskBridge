import React, { useState, useRef, useEffect } from 'react';

export interface AdminSelectOption {
  value: string;
  label: string;
}

export interface AdminSelectProps {
  value: string;
  onChange: (value: string) => void;
  options: (string | AdminSelectOption)[];
  placeholder?: string;
  className?: string;
  style?: React.CSSProperties;
  title?: string;
  disabled?: boolean;
}

export const AdminSelect: React.FC<AdminSelectProps> = ({
  value,
  onChange,
  options,
  placeholder,
  className = '',
  style,
  title,
  disabled = false,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [isMobile, setIsMobile] = useState<boolean>(() => {
    if (typeof window !== 'undefined') {
      return window.innerWidth <= 768;
    }
    return false;
  });

  const containerRef = useRef<HTMLDivElement>(null);

  // Track window resize to toggle between desktop dropdown and mobile sheet
  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth <= 768);
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Close desktop dropdown on click outside
  useEffect(() => {
    if (!isOpen) return;

    const handleClickOutside = (e: MouseEvent | TouchEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        // If it's desktop, close immediately
        if (!isMobile) {
          setIsOpen(false);
        }
      }
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('touchstart', handleClickOutside);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('touchstart', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, isMobile]);

  // Lock body scroll when mobile bottom sheet is open
  useEffect(() => {
    if (isOpen && isMobile) {
      const originalOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      return () => {
        document.body.style.overflow = originalOverflow;
      };
    }
  }, [isOpen, isMobile]);

  // Normalize options array
  const normalizedOptions: AdminSelectOption[] = options.map((opt) => {
    if (typeof opt === 'string') {
      return { value: opt, label: opt };
    }
    return opt;
  });

  const selectedOption = normalizedOptions.find((opt) => opt.value === value);
  const displayLabel = selectedOption ? selectedOption.label : placeholder || value || 'Select...';
  const modalTitle = title || placeholder || 'Select Option';

  const handleSelect = (val: string) => {
    onChange(val);
    setIsOpen(false);
  };

  return (
    <div
      ref={containerRef}
      className={`admin-custom-select-wrap ${className}`}
      style={{ position: 'relative', display: 'inline-block', ...style }}
    >
      {/* Trigger Button */}
      <button
        type="button"
        className="admin-custom-select-trigger"
        onClick={() => !disabled && setIsOpen((prev) => !prev)}
        disabled={disabled}
        title={title}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
      >
        <span className="admin-custom-select-label">{displayLabel}</span>
        <svg
          className={`admin-custom-select-chevron ${isOpen ? 'open' : ''}`}
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
        >
          <polyline points="6 9 12 15 18 9" />
        </svg>
      </button>

      {/* Desktop Anchored Dropdown Menu */}
      {isOpen && !isMobile && (
        <div className="admin-custom-select-menu" role="listbox">
          {normalizedOptions.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <div
                key={opt.value}
                className={`admin-custom-select-item ${isSelected ? 'selected' : ''}`}
                onClick={() => handleSelect(opt.value)}
                role="option"
                aria-selected={isSelected}
              >
                <span>{opt.label}</span>
                {isSelected && (
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Mobile Touch-Friendly Bottom Sheet Modal */}
      {isOpen && isMobile && (
        <div className="admin-select-mobile-overlay" onClick={() => setIsOpen(false)}>
          <div
            className="admin-select-mobile-sheet"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            {/* Sheet Handle */}
            <div className="admin-select-sheet-handle-bar">
              <div className="admin-select-sheet-handle" />
            </div>

            {/* Sheet Header */}
            <div className="admin-select-sheet-header">
              <span className="admin-select-sheet-title">{modalTitle}</span>
              <button
                type="button"
                className="admin-select-sheet-close"
                onClick={() => setIsOpen(false)}
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            {/* Options List */}
            <div className="admin-select-sheet-list">
              {normalizedOptions.map((opt) => {
                const isSelected = opt.value === value;
                return (
                  <button
                    key={opt.value}
                    type="button"
                    className={`admin-select-sheet-option ${isSelected ? 'selected' : ''}`}
                    onClick={() => handleSelect(opt.value)}
                  >
                    <span className="admin-select-sheet-option-label">{opt.label}</span>
                    {isSelected && (
                      <div className="admin-select-sheet-check">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                          <polyline points="20 6 9 17 4 12" />
                        </svg>
                      </div>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Cancel Button */}
            <div className="admin-select-sheet-footer">
              <button
                type="button"
                className="admin-select-sheet-cancel-btn"
                onClick={() => setIsOpen(false)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
