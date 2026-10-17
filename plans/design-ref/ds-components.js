/* @ds-bundle: {"format":4,"namespace":"ApproximatelyScientificDesignSystem_b8396a","components":[{"name":"Annotation","sourcePath":"components/core/Annotation.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Tag","sourcePath":"components/core/Tag.jsx"},{"name":"DataTable","sourcePath":"components/data/DataTable.jsx"},{"name":"Equation","sourcePath":"components/data/Equation.jsx"},{"name":"FigureFrame","sourcePath":"components/data/FigureFrame.jsx"},{"name":"Readout","sourcePath":"components/data/Readout.jsx"},{"name":"Sparkplot","sourcePath":"components/data/Sparkplot.jsx"},{"name":"StatBlock","sourcePath":"components/data/StatBlock.jsx"},{"name":"Callout","sourcePath":"components/feedback/Callout.jsx"},{"name":"Dialog","sourcePath":"components/feedback/Dialog.jsx"},{"name":"ProgressMeter","sourcePath":"components/feedback/ProgressMeter.jsx"},{"name":"Tooltip","sourcePath":"components/feedback/Tooltip.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"SegmentedControl","sourcePath":"components/navigation/SegmentedControl.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"Tabs","sourcePath":"components/navigation/Tabs.jsx"}],"sourceHashes":{"components/core/Annotation.jsx":"517ceabf9b0f","components/core/Badge.jsx":"70ca87a5abe5","components/core/Button.jsx":"238fb4664846","components/core/Card.jsx":"d1cfcc28623b","components/core/IconButton.jsx":"dec6283ea21e","components/core/Tag.jsx":"ee8f32c5af77","components/data/DataTable.jsx":"290a7819052c","components/data/Equation.jsx":"db6acc6dcf27","components/data/FigureFrame.jsx":"ce4a643393ab","components/data/Readout.jsx":"b685f23cd1df","components/data/Sparkplot.jsx":"0253e61438a7","components/data/StatBlock.jsx":"ac7586fe6370","components/feedback/Callout.jsx":"8c9da4f96157","components/feedback/Dialog.jsx":"f69aad66ba42","components/feedback/ProgressMeter.jsx":"99b2c62ee487","components/feedback/Tooltip.jsx":"0b8dd1587ff4","components/forms/Checkbox.jsx":"1d5b0452af18","components/forms/Input.jsx":"f3121c1fdad5","components/forms/Radio.jsx":"df0d859343e6","components/forms/Select.jsx":"97eeff9c4fe4","components/forms/Switch.jsx":"eb4779c40f65","components/navigation/SegmentedControl.jsx":"f7cae2f8ae49","components/navigation/TabBar.jsx":"aeb73181c48a","components/navigation/Tabs.jsx":"7f8fe8e7477b","ui_kits/app/AnalysisScreen.jsx":"8e47daa25740","ui_kits/app/App.jsx":"7b0e11e84b17","ui_kits/app/Chrome.jsx":"3b1015c9c0c8","ui_kits/app/LabScreen.jsx":"0cfc511cd9c9","ui_kits/app/LogScreen.jsx":"b05f07e7fac1","ui_kits/app/RideScreen.jsx":"4fd66e2c3616","ui_kits/website/Hero.jsx":"41e7b84e8154","ui_kits/website/Sections.jsx":"91ed801f755a","ui_kits/website/Site.jsx":"09a5cd476a40","ui_kits/website/SiteChrome.jsx":"a134ca807a52"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.ApproximatelyScientificDesignSystem_b8396a = window.ApproximatelyScientificDesignSystem_b8396a || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Annotation.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Annotation({
  marker,
  children,
  align = "left",
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: "var(--sp-3)",
      justifyContent: align === "right" ? "flex-end" : "flex-start",
      ...style
    }
  }, rest), marker && /*#__PURE__*/React.createElement("span", {
    style: {
      flex: "none",
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)"
    }
  }, marker), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: "none",
      height: 1,
      minWidth: "var(--sp-6)",
      alignSelf: "center",
      background: "var(--rule-hair)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      color: "var(--text-muted)"
    }
  }, children));
}
Object.assign(__ds_scope, { Annotation });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Annotation.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  neutral: {
    background: "var(--paper-200)",
    color: "var(--ink-700)",
    borderColor: "var(--rule-solid)"
  },
  blueprint: {
    background: "var(--blueprint-100)",
    color: "var(--blueprint-700)",
    borderColor: "var(--blueprint-200)"
  },
  measure: {
    background: "var(--signal-100)",
    color: "var(--signal-600)",
    borderColor: "var(--signal-300)"
  },
  ok: {
    background: "var(--ok-100)",
    color: "var(--ok-600)",
    borderColor: "var(--ok-500)"
  },
  warn: {
    background: "var(--warn-100)",
    color: "var(--warn-600)",
    borderColor: "var(--warn-500)"
  },
  err: {
    background: "var(--err-100)",
    color: "var(--err-600)",
    borderColor: "var(--err-500)"
  }
};
function Badge({
  tone = "neutral",
  children,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "var(--sp-2)",
      padding: "2px 6px",
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-2xs)",
      fontWeight: "var(--weight-medium)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      whiteSpace: "nowrap",
      borderStyle: "solid",
      borderWidth: "var(--hair)",
      borderRadius: "var(--radius-xs)",
      ...TONES[tone],
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const PAD = {
  sm: "7px 14px",
  md: "11px 20px",
  lg: "15px 28px"
};
const FS = {
  sm: "var(--text-2xs)",
  md: "var(--text-xs)",
  lg: "var(--text-sm)"
};
function Button({
  variant = "primary",
  size = "md",
  index,
  disabled = false,
  type = "button",
  children,
  onClick,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [down, setDown] = React.useState(false);
  const skins = {
    primary: {
      background: hover ? "var(--blueprint-700)" : "var(--blueprint-600)",
      color: "var(--paper-000)",
      borderColor: "var(--blueprint-700)"
    },
    secondary: {
      background: hover ? "var(--paper-100)" : "var(--paper-000)",
      color: "var(--ink-900)",
      borderColor: "var(--ink-900)"
    },
    ghost: {
      background: hover ? "var(--paper-200)" : "transparent",
      color: "var(--ink-700)",
      borderColor: "transparent"
    },
    measure: {
      background: hover ? "var(--signal-600)" : "var(--signal-500)",
      color: "var(--measure-on)",
      borderColor: "var(--signal-500)"
    }
  };
  const skin = skins[variant] || skins.primary;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    disabled: disabled,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setDown(false);
    },
    onMouseDown: () => setDown(true),
    onMouseUp: () => setDown(false),
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "var(--sp-3)",
      padding: PAD[size],
      fontFamily: "var(--font-sans)",
      fontSize: FS[size],
      fontWeight: "var(--weight-semibold)",
      letterSpacing: "0.055em",
      textTransform: "uppercase",
      whiteSpace: "nowrap",
      borderStyle: "solid",
      borderWidth: "var(--hair)",
      borderRadius: "1px",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .38 : 1,
      transform: down && !disabled ? "translate(1.5px,1.5px)" : "none",
      boxShadow: disabled ? "none" : down ? "0.5px 0.5px 0 0 var(--key-shadow)" : "2px 2px 0 0 var(--key-shadow)",
      transition: "background var(--dur-fast) var(--ease-plot),transform var(--dur-fast) var(--ease-plot),box-shadow var(--dur-fast) var(--ease-plot)",
      ...skin,
      ...style
    }
  }, rest), index != null && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontWeight: "var(--weight-regular)",
      fontSize: "var(--text-2xs)",
      opacity: .62,
      letterSpacing: 0
    }
  }, String(index).padStart(2, "0")), children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Card({
  label,
  title,
  subtitle,
  footer,
  inset = false,
  children,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("section", _extends({
    style: {
      background: "var(--surface-card)",
      border: "var(--hair) solid var(--border-default)",
      borderRadius: "var(--radius-sm)",
      boxShadow: "var(--shadow-print)",
      padding: inset ? 0 : "var(--sp-6)",
      ...style
    }
  }, rest), (label || title || subtitle) && /*#__PURE__*/React.createElement("header", {
    style: {
      padding: inset ? "var(--sp-6) var(--sp-6) 0" : 0,
      marginBottom: "var(--sp-5)"
    }
  }, label && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)",
      marginBottom: "var(--sp-3)"
    }
  }, label), title && /*#__PURE__*/React.createElement("h3", {
    style: {
      font: "var(--type-title)",
      fontSize: "var(--text-lg)",
      color: "var(--text-strong)",
      margin: 0
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("p", {
    style: {
      font: "var(--type-subtitle)",
      fontSize: "var(--text-base)",
      color: "var(--text-muted)",
      margin: "var(--sp-2) 0 0"
    }
  }, subtitle)), children, footer && /*#__PURE__*/React.createElement("footer", {
    style: {
      marginTop: "var(--sp-6)",
      paddingTop: "var(--sp-4)",
      borderTop: "var(--hair) solid var(--rule-hair)",
      font: "var(--type-data)",
      color: "var(--text-muted)"
    }
  }, footer));
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const SZ = {
  sm: 28,
  md: 34,
  lg: 44
};
function IconButton({
  label,
  variant = "secondary",
  size = "md",
  disabled = false,
  children,
  onClick,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [down, setDown] = React.useState(false);
  const skins = {
    primary: {
      background: hover ? "var(--blueprint-700)" : "var(--blueprint-600)",
      color: "var(--paper-000)",
      borderColor: "var(--blueprint-700)"
    },
    secondary: {
      background: hover ? "var(--paper-100)" : "var(--paper-000)",
      color: "var(--ink-900)",
      borderColor: "var(--ink-900)"
    },
    ghost: {
      background: hover ? "var(--paper-200)" : "transparent",
      color: "var(--ink-700)",
      borderColor: "transparent"
    }
  };
  const skin = skins[variant] || skins.secondary;
  const d = SZ[size];
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    title: label,
    disabled: disabled,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setDown(false);
    },
    onMouseDown: () => setDown(true),
    onMouseUp: () => setDown(false),
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      width: d,
      height: d,
      padding: 0,
      borderStyle: "solid",
      borderWidth: "var(--hair)",
      borderRadius: "var(--radius-sm)",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .38 : 1,
      transform: down && !disabled ? "translate(1px,1px)" : "none",
      transition: "background var(--dur-fast) var(--ease-plot),transform var(--dur-fast) var(--ease-plot)",
      ...skin,
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/Tag.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Tag({
  children,
  onRemove,
  active = false,
  onClick,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const clickable = !!onClick;
  return /*#__PURE__*/React.createElement("span", _extends({
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "var(--sp-3)",
      padding: "3px 8px",
      fontFamily: "var(--font-sans)",
      fontSize: "var(--text-xs)",
      fontWeight: "var(--weight-medium)",
      background: active ? "var(--ink-900)" : hover && clickable ? "var(--paper-200)" : "var(--paper-000)",
      color: active ? "var(--paper-000)" : "var(--ink-700)",
      border: "var(--hair) solid " + (active ? "var(--ink-900)" : "var(--rule-solid)"),
      borderRadius: "var(--radius-sm)",
      cursor: clickable ? "pointer" : "default",
      transition: "background var(--dur-fast) var(--ease-plot)",
      ...style
    }
  }, rest), children, onRemove && /*#__PURE__*/React.createElement("span", {
    role: "button",
    "aria-label": "Remove",
    onClick: e => {
      e.stopPropagation();
      onRemove(e);
    },
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-2xs)",
      opacity: .6,
      cursor: "pointer"
    }
  }, "\xD7"));
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tag.jsx", error: String((e && e.message) || e) }); }

// components/data/DataTable.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function DataTable({
  columns = [],
  rows = [],
  caption,
  dense = false,
  style,
  ...rest
}) {
  const pad = dense ? "5px 8px" : "8px 11px";
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("table", {
    style: {
      width: "100%",
      borderCollapse: "collapse",
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-xs)",
      fontVariantNumeric: "tabular-nums"
    }
  }, caption && /*#__PURE__*/React.createElement("caption", {
    style: {
      captionSide: "top",
      textAlign: "left",
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)",
      paddingBottom: "var(--sp-3)"
    }
  }, caption), /*#__PURE__*/React.createElement("thead", null, /*#__PURE__*/React.createElement("tr", null, columns.map(c => {
    const key = typeof c === "string" ? c : c.key;
    const label = typeof c === "string" ? c : c.label;
    const align = typeof c === "string" ? "left" : c.align || "left";
    return /*#__PURE__*/React.createElement("th", {
      key: key,
      style: {
        textAlign: align,
        padding: pad,
        borderBottom: "var(--hair) solid var(--ink-900)",
        font: "var(--type-label)",
        letterSpacing: "var(--tracking-label)",
        textTransform: "uppercase",
        color: "var(--text-muted)",
        whiteSpace: "nowrap"
      }
    }, label);
  }))), /*#__PURE__*/React.createElement("tbody", null, rows.map((r, i) => /*#__PURE__*/React.createElement("tr", {
    key: i,
    style: {
      background: i % 2 ? "var(--paper-100)" : "transparent"
    }
  }, columns.map(c => {
    const key = typeof c === "string" ? c : c.key;
    const align = typeof c === "string" ? "left" : c.align || "left";
    return /*#__PURE__*/React.createElement("td", {
      key: key,
      style: {
        textAlign: align,
        padding: pad,
        borderBottom: "var(--hair) solid var(--rule-hair)",
        color: "var(--text-body)"
      }
    }, r[key]);
  }))))));
}
Object.assign(__ds_scope, { DataTable });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/DataTable.jsx", error: String((e && e.message) || e) }); }

// components/data/Equation.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Equation({
  number,
  children,
  note,
  display = true,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("figure", _extends({
    style: {
      display: "grid",
      gridTemplateColumns: "1fr auto",
      alignItems: "center",
      gap: "var(--sp-5)",
      margin: 0,
      padding: display ? "var(--sp-6) 0" : 0,
      borderTop: display ? "var(--hair) solid var(--rule-hair)" : "none",
      borderBottom: display ? "var(--hair) solid var(--rule-hair)" : "none",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-display)",
      fontStyle: "italic",
      fontSize: display ? "var(--text-lg)" : "var(--text-base)",
      color: "var(--text-strong)",
      letterSpacing: ".01em"
    }
  }, children), number != null && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-data)",
      color: "var(--text-annotation)"
    }
  }, "(", number, ")"), note && /*#__PURE__*/React.createElement("figcaption", {
    style: {
      gridColumn: "1 / -1",
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)"
    }
  }, note));
}
Object.assign(__ds_scope, { Equation });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/Equation.jsx", error: String((e && e.message) || e) }); }

// components/data/FigureFrame.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function FigureFrame({
  number,
  caption,
  source,
  pattern = "graph",
  height,
  children,
  style,
  ...rest
}) {
  const bgImage = pattern === "graph" ? "var(--pattern-graph)" : pattern === "dot" ? "var(--pattern-dot)" : pattern === "hatch" ? "var(--pattern-hatch)" : "none";
  return /*#__PURE__*/React.createElement("figure", _extends({
    style: {
      margin: 0,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: height,
      minHeight: height ? undefined : 120,
      backgroundColor: "var(--surface-card)",
      backgroundImage: bgImage,
      backgroundSize: "var(--pattern-tile)",
      border: "var(--hair) solid var(--border-default)",
      display: "grid",
      placeItems: "stretch",
      overflow: "hidden"
    }
  }, children), (caption || number != null) && /*#__PURE__*/React.createElement("figcaption", {
    style: {
      display: "flex",
      gap: "var(--sp-3)",
      marginTop: "var(--sp-3)",
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-muted)"
    }
  }, number != null && /*#__PURE__*/React.createElement("span", {
    style: {
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)",
      flex: "none"
    }
  }, "FIG. ", String(number).padStart(2, "0")), /*#__PURE__*/React.createElement("span", null, caption, source && /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-faint)"
    }
  }, " \u2014 ", source))));
}
Object.assign(__ds_scope, { FigureFrame });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/FigureFrame.jsx", error: String((e && e.message) || e) }); }

// components/data/Readout.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const SZ = {
  panel: {
    fs: "var(--text-5xl)",
    pad: "var(--sp-4) var(--sp-5)",
    gap: "var(--sp-3)",
    unit: "var(--text-2xs)"
  },
  inline: {
    fs: "var(--text-lg)",
    pad: "3px var(--sp-3)",
    gap: "var(--sp-2)",
    unit: "var(--text-2xs)"
  }
};

/** Fixed decimals, always shown, then padded to a fixed integer width. The sign occupies a
 *  permanent slot (hidden when positive) so the field never reflows between +/-. */
function frame(value, digits, decimals) {
  const n = typeof value === "number" ? value : parseFloat(value);
  if (!isFinite(n)) return {
    sign: "",
    ghost: "",
    live: String(value)
  };
  const s = Math.abs(n).toFixed(decimals);
  const int = s.split(".")[0];
  const pad = Math.max(0, digits - int.length);
  return {
    sign: n < 0 ? "-" : "",
    ghost: "0".repeat(pad),
    live: s
  };
}
function Readout({
  value,
  digits = 3,
  decimals = 1,
  unit,
  size = "panel",
  tone = "ink",
  approx = false,
  label,
  style,
  ...rest
}) {
  const sz = SZ[size] || SZ.panel;
  const {
    sign,
    ghost,
    live
  } = frame(value, digits, decimals);
  const digit = {
    ink: "var(--paper-000)",
    measure: "var(--signal-500)",
    plot: "var(--plot-5)"
  }[tone] || "var(--paper-000)";
  const [flash, setFlash] = React.useState(false);
  const first = React.useRef(true);
  React.useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    setFlash(true);
    const t = setTimeout(() => setFlash(false), 140);
    return () => clearTimeout(t);
  }, [value]);
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "inline-flex",
      flexDirection: "column",
      alignItems: "stretch",
      gap: 2,
      ...style
    }
  }, rest), label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      fontSize: "var(--text-2xs)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)",
      marginBottom: 2
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--well-surface)",
      boxShadow: flash ? "var(--inset-well),inset 0 0 0 1px " + digit : "var(--inset-well)",
      padding: sz.pad,
      borderRadius: 1,
      transition: "box-shadow 90ms var(--ease-linear)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      fontFamily: "var(--font-mono)",
      fontSize: sz.fs,
      fontWeight: "var(--weight-regular)",
      lineHeight: 1,
      letterSpacing: "-.01em",
      fontVariantNumeric: "tabular-nums",
      textAlign: "right",
      color: digit
    }
  }, approx && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      height: "1em",
      verticalAlign: "top",
      lineHeight: 1,
      color: "var(--ink-300)",
      paddingRight: ".14em"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: ".62em",
      lineHeight: 1
    }
  }, "\u2248")), /*#__PURE__*/React.createElement("span", {
    style: {
      visibility: sign ? "visible" : "hidden"
    }
  }, "\u2212"), ghost && /*#__PURE__*/React.createElement("span", {
    style: {
      opacity: .12
    }
  }, ghost), live)), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-eyebrow)",
      fontSize: sz.unit,
      fontWeight: "var(--weight-semibold)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-faint)",
      textAlign: "right"
    }
  }, unit));
}
Object.assign(__ds_scope, { Readout });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/Readout.jsx", error: String((e && e.message) || e) }); }

// components/data/Sparkplot.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Sparkplot({
  data = [],
  tone = "blueprint",
  fill = true,
  height = 64,
  strokeWidth = 1.5,
  baseline = false,
  style,
  ...rest
}) {
  const stroke = {
    blueprint: "var(--blueprint-600)",
    measure: "var(--plot-3)",
    ink: "var(--ink-900)",
    ok: "var(--ok-500)",
    plot1: "var(--plot-1)",
    plot2: "var(--plot-2)",
    plot3: "var(--plot-3)",
    plot4: "var(--plot-4)",
    plot5: "var(--plot-5-line)",
    plot6: "var(--plot-6-line)"
  }[tone] || "var(--plot-3)";
  const n = data.length;
  const max = n ? Math.max(...data) : 1;
  const min = n ? Math.min(...data) : 0;
  const span = max - min || 1;
  const pts = data.map((v, i) => [i / (n - 1 || 1) * 100, 100 - (v - min) / span * 100]);
  const line = pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(2) + " " + p[1].toFixed(2)).join(" ");
  const area = line + " L100 100 L0 100 Z";
  return /*#__PURE__*/React.createElement("svg", _extends({
    viewBox: "0 0 100 100",
    preserveAspectRatio: "none",
    style: {
      display: "block",
      width: "100%",
      height: height,
      ...style
    }
  }, rest), fill && /*#__PURE__*/React.createElement("path", {
    d: area,
    fill: stroke,
    opacity: ".12"
  }), baseline && /*#__PURE__*/React.createElement("line", {
    x1: "0",
    y1: "100",
    x2: "100",
    y2: "100",
    stroke: "var(--rule-solid)",
    strokeWidth: "1",
    vectorEffect: "non-scaling-stroke"
  }), /*#__PURE__*/React.createElement("path", {
    d: line,
    fill: "none",
    stroke: stroke,
    strokeWidth: strokeWidth,
    vectorEffect: "non-scaling-stroke",
    strokeLinejoin: "round"
  }));
}
Object.assign(__ds_scope, { Sparkplot });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/Sparkplot.jsx", error: String((e && e.message) || e) }); }

// components/data/StatBlock.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const FIG = {
  sm: "var(--text-lg)",
  md: "var(--text-xl)",
  lg: "var(--text-3xl)"
};
function StatBlock({
  label,
  value,
  unit,
  delta,
  approx = false,
  tone = "ink",
  size = "lg",
  align = "left",
  style,
  ...rest
}) {
  const color = {
    ink: "var(--text-strong)",
    blueprint: "var(--blueprint-600)",
    measure: "var(--signal-500)"
  }[tone];
  const dTone = delta && String(delta).trim().startsWith("-") ? "var(--err-600)" : "var(--ok-600)";
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-2)",
      alignItems: align === "right" ? "flex-end" : "flex-start",
      ...style
    }
  }, rest), label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)"
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: "var(--sp-2)"
    }
  }, approx && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: size === "lg" ? "var(--text-lg)" : "var(--text-base)",
      color: "var(--text-faint)",
      lineHeight: 1
    }
  }, "\u2248"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-figure)",
      fontSize: FIG[size] || FIG.lg,
      color: color,
      fontVariantNumeric: "tabular-nums"
    }
  }, value), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-sm)",
      color: "var(--text-muted)"
    }
  }, unit)), delta && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: dTone
    }
  }, delta));
}
Object.assign(__ds_scope, { StatBlock });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/StatBlock.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Callout.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  note: {
    rule: "var(--blueprint-600)",
    label: "NOTE",
    color: "var(--blueprint-700)",
    bg: "var(--paper-000)"
  },
  method: {
    rule: "var(--ink-900)",
    label: "METHOD",
    color: "var(--ink-900)",
    bg: "var(--paper-000)"
  },
  caution: {
    rule: "var(--warn-500)",
    label: "CAUTION",
    color: "var(--warn-600)",
    bg: "var(--paper-000)"
  },
  error: {
    rule: "var(--err-500)",
    label: "ERROR",
    color: "var(--err-600)",
    bg: "var(--paper-000)"
  },
  result: {
    rule: "var(--ok-500)",
    label: "RESULT",
    color: "var(--ok-600)",
    bg: "var(--paper-000)"
  }
};
function Callout({
  tone = "note",
  label,
  title,
  children,
  style,
  ...rest
}) {
  const t = TONES[tone] || TONES.note;
  return /*#__PURE__*/React.createElement("aside", _extends({
    style: {
      background: t.bg,
      borderTop: "var(--rule-w) solid " + t.rule,
      borderRight: "var(--hair) solid var(--border-default)",
      borderBottom: "var(--hair) solid var(--border-default)",
      borderLeft: "var(--hair) solid var(--border-default)",
      padding: "var(--sp-5) var(--sp-6)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: t.color,
      marginBottom: "var(--sp-3)"
    }
  }, label || t.label), title && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-title)",
      fontSize: "var(--text-md)",
      color: "var(--text-strong)",
      marginBottom: "var(--sp-2)"
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      color: "var(--text-body)"
    }
  }, children));
}
Object.assign(__ds_scope, { Callout });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Callout.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Dialog.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Dialog({
  open = false,
  label,
  title,
  children,
  footer,
  onClose,
  width = 460,
  style,
  ...rest
}) {
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    role: "presentation",
    onClick: onClose,
    style: {
      position: "fixed",
      inset: 0,
      zIndex: 60,
      display: "grid",
      placeItems: "center",
      padding: "var(--sp-6)",
      background: "var(--scrim)",
      backdropFilter: "var(--blur-sheet)"
    }
  }, /*#__PURE__*/React.createElement("div", _extends({
    role: "dialog",
    "aria-modal": "true",
    "aria-label": title,
    onClick: e => e.stopPropagation(),
    style: {
      width: "100%",
      maxWidth: width,
      background: "var(--surface-card)",
      border: "var(--hair) solid var(--ink-900)",
      borderRadius: "var(--radius-sm)",
      boxShadow: "var(--shadow-raise)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("header", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      justifyContent: "space-between",
      gap: "var(--sp-5)",
      padding: "var(--sp-6)",
      borderBottom: "var(--hair) solid var(--rule-hair)"
    }
  }, /*#__PURE__*/React.createElement("div", null, label && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)",
      marginBottom: "var(--sp-2)"
    }
  }, label), /*#__PURE__*/React.createElement("h3", {
    style: {
      font: "var(--type-title)",
      fontSize: "var(--text-lg)",
      color: "var(--text-strong)",
      margin: 0
    }
  }, title)), onClose && /*#__PURE__*/React.createElement("button", {
    type: "button",
    "aria-label": "Close",
    onClick: onClose,
    style: {
      border: 0,
      background: "transparent",
      cursor: "pointer",
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-md)",
      color: "var(--text-muted)",
      lineHeight: 1,
      padding: 2
    }
  }, "\xD7")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "var(--sp-6)",
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      color: "var(--text-body)"
    }
  }, children), footer && /*#__PURE__*/React.createElement("footer", {
    style: {
      display: "flex",
      justifyContent: "flex-end",
      gap: "var(--sp-4)",
      padding: "var(--sp-5) var(--sp-6)",
      borderTop: "var(--hair) solid var(--rule-hair)",
      background: "var(--paper-100)"
    }
  }, footer)));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressMeter.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function ProgressMeter({
  value = 0,
  max = 100,
  label,
  unit,
  tone = "blueprint",
  ticks = 10,
  readout = true,
  style,
  ...rest
}) {
  const pct = Math.max(0, Math.min(100, value / max * 100));
  const fill = {
    blueprint: "var(--blueprint-600)",
    measure: "var(--signal-500)",
    ok: "var(--ok-500)",
    ink: "var(--ink-900)"
  }[tone];
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-2)",
      ...style
    }
  }, rest), (label || readout) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "baseline",
      gap: "var(--sp-4)"
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)"
    }
  }, label), readout && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontVariantNumeric: "tabular-nums",
      color: "var(--text-strong)"
    }
  }, value, unit ? " " + unit : "", /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-faint)"
    }
  }, " / ", max, unit ? " " + unit : ""))), /*#__PURE__*/React.createElement("div", {
    role: "progressbar",
    "aria-valuenow": value,
    "aria-valuemax": max,
    style: {
      position: "relative",
      height: 10,
      background: "var(--paper-200)",
      border: "var(--hair) solid var(--rule-solid)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      backgroundImage: "repeating-linear-gradient(to right,var(--rule-solid) 0 1px,transparent 1px " + 100 / ticks + "%)",
      opacity: .7
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      bottom: 0,
      width: pct + "%",
      background: fill,
      transition: "width var(--dur-plot) var(--ease-plot)"
    }
  })));
}
Object.assign(__ds_scope, { ProgressMeter });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressMeter.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Tooltip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Tooltip({
  content,
  placement = "top",
  children,
  style,
  ...rest
}) {
  const [open, setOpen] = React.useState(false);
  const pos = placement === "bottom" ? {
    top: "calc(100% + 6px)"
  } : {
    bottom: "calc(100% + 6px)"
  };
  return /*#__PURE__*/React.createElement("span", _extends({
    onMouseEnter: () => setOpen(true),
    onMouseLeave: () => setOpen(false),
    onFocus: () => setOpen(true),
    onBlur: () => setOpen(false),
    style: {
      position: "relative",
      display: "inline-flex",
      ...style
    }
  }, rest), children, open && /*#__PURE__*/React.createElement("span", {
    role: "tooltip",
    style: {
      position: "absolute",
      left: "50%",
      transform: "translateX(-50%)",
      ...pos,
      zIndex: 40,
      whiteSpace: "nowrap",
      padding: "4px 7px",
      background: "var(--ink-900)",
      color: "var(--paper-000)",
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-2xs)",
      letterSpacing: "var(--tracking-mono)",
      borderRadius: "var(--radius-xs)"
    }
  }, content));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Tooltip.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Checkbox({
  label,
  hint,
  checked,
  defaultChecked,
  onChange,
  disabled,
  style,
  ...rest
}) {
  const [inner, setInner] = React.useState(!!defaultChecked);
  const on = checked !== undefined ? checked : inner;
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "inline-flex",
      alignItems: "flex-start",
      gap: "var(--sp-4)",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .42 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "checkbox",
    checked: on,
    disabled: disabled,
    onChange: e => {
      setInner(e.target.checked);
      onChange && onChange(e);
    },
    style: {
      position: "absolute",
      opacity: 0,
      width: 0,
      height: 0
    }
  }, rest)), /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      flex: "none",
      width: 15,
      height: 15,
      marginTop: 1,
      display: "grid",
      placeItems: "center",
      background: on ? "var(--ink-900)" : "var(--surface-card)",
      border: "var(--hair) solid var(--ink-900)",
      borderRadius: "var(--radius-xs)",
      transition: "background var(--dur-fast) var(--ease-plot)"
    }
  }, on && /*#__PURE__*/React.createElement("svg", {
    width: "10",
    height: "10",
    viewBox: "0 0 10 10",
    fill: "none",
    stroke: "var(--paper-000)",
    strokeWidth: "1.6"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1.5 5.4 3.9 7.8 8.6 2.2"
  }))), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      color: "var(--text-strong)"
    }
  }, label), hint && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)",
      marginTop: 2
    }
  }, hint)));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Input({
  label,
  hint,
  error,
  unit,
  mono = false,
  id,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const uid = React.useMemo(() => id || "in-" + Math.random().toString(36).slice(2, 7), [id]);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-2)",
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("label", {
    htmlFor: uid,
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-muted)"
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "stretch",
      background: "var(--surface-card)",
      border: "var(--hair) solid " + (error ? "var(--err-500)" : focus ? "var(--ink-900)" : "var(--border-default)"),
      borderRadius: "var(--radius-sm)",
      boxShadow: focus ? "var(--inset-focus)" : "none",
      transition: "border-color var(--dur-fast) var(--ease-plot)"
    }
  }, /*#__PURE__*/React.createElement("input", _extends({
    id: uid,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      flex: 1,
      minWidth: 0,
      padding: "8px 11px",
      border: 0,
      outline: "none",
      background: "transparent",
      color: "var(--text-strong)",
      fontFamily: mono ? "var(--font-mono)" : "var(--font-sans)",
      fontSize: "var(--text-sm)",
      fontVariantNumeric: "tabular-nums"
    }
  }, rest)), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      alignItems: "center",
      padding: "0 9px",
      borderLeft: "var(--hair) solid var(--border-default)",
      background: "var(--paper-100)",
      font: "var(--type-label)",
      color: "var(--text-annotation)"
    }
  }, unit)), (hint || error) && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: error ? "var(--err-600)" : "var(--text-faint)"
    }
  }, error || hint));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Radio({
  label,
  hint,
  name,
  value,
  checked,
  onChange,
  disabled,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "inline-flex",
      alignItems: "flex-start",
      gap: "var(--sp-4)",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .42 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "radio",
    name: name,
    value: value,
    checked: checked,
    disabled: disabled,
    onChange: onChange,
    style: {
      position: "absolute",
      opacity: 0,
      width: 0,
      height: 0
    }
  }, rest)), /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      flex: "none",
      width: 15,
      height: 15,
      marginTop: 1,
      display: "grid",
      placeItems: "center",
      background: "var(--surface-card)",
      border: "var(--hair) solid var(--ink-900)",
      borderRadius: "var(--radius-pill)"
    }
  }, checked && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 7,
      height: 7,
      borderRadius: "var(--radius-pill)",
      background: "var(--ink-900)"
    }
  })), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      color: "var(--text-strong)"
    }
  }, label), hint && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "block",
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)",
      marginTop: 2
    }
  }, hint)));
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Select({
  label,
  hint,
  options = [],
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-2)",
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-muted)"
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      display: "flex"
    }
  }, /*#__PURE__*/React.createElement("select", _extends({
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      appearance: "none",
      flex: 1,
      padding: "8px 30px 8px 11px",
      background: "var(--surface-card)",
      color: "var(--text-strong)",
      border: "var(--hair) solid " + (focus ? "var(--ink-900)" : "var(--border-default)"),
      borderRadius: "var(--radius-sm)",
      fontFamily: "var(--font-sans)",
      fontSize: "var(--text-sm)",
      outline: "none",
      cursor: "pointer"
    }
  }, rest), options.map(o => {
    const v = typeof o === "string" ? o : o.value;
    const l = typeof o === "string" ? o : o.label;
    return /*#__PURE__*/React.createElement("option", {
      key: v,
      value: v
    }, l);
  })), /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      position: "absolute",
      right: 10,
      top: "50%",
      transform: "translateY(-50%)",
      fontFamily: "var(--font-mono)",
      fontSize: "var(--text-2xs)",
      color: "var(--text-annotation)",
      pointerEvents: "none"
    }
  }, "\u25BE")), hint && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)"
    }
  }, hint));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Switch({
  label,
  checked,
  defaultChecked,
  onChange,
  disabled,
  style,
  ...rest
}) {
  const [inner, setInner] = React.useState(!!defaultChecked);
  const on = checked !== undefined ? checked : inner;
  const toggle = () => {
    if (disabled) return;
    const v = !on;
    setInner(v);
    onChange && onChange(v);
  };
  return /*#__PURE__*/React.createElement("label", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: "var(--sp-4)",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? .42 : 1,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("button", {
    type: "button",
    role: "switch",
    "aria-checked": on,
    onClick: toggle,
    style: {
      position: "relative",
      width: 42,
      height: 20,
      padding: 0,
      background: on ? "var(--blueprint-600)" : "var(--paper-200)",
      border: "var(--hair) solid " + (on ? "var(--blueprint-700)" : "var(--rule-solid)"),
      borderRadius: "var(--radius-sm)",
      cursor: "inherit",
      transition: "background var(--dur-base) var(--ease-plot)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      position: "absolute",
      top: 1,
      left: on ? 23 : 1,
      width: 16,
      height: 16,
      background: "var(--paper-000)",
      border: "var(--hair) solid " + (on ? "var(--blueprint-700)" : "var(--rule-solid)"),
      transition: "left var(--dur-base) var(--ease-plot)"
    }
  })), label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      color: "var(--text-strong)"
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      color: "var(--text-annotation)"
    }
  }, on ? "ON" : "OFF"));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SegmentedControl.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function SegmentedControl({
  options = [],
  value,
  onChange,
  size = "md",
  style,
  ...rest
}) {
  const [inner, setInner] = React.useState(value || options[0] && (options[0].value || options[0]));
  const active = value !== undefined ? value : inner;
  const pad = size === "sm" ? "4px 9px" : "6px 13px";
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "group",
    style: {
      display: "inline-flex",
      alignSelf: "flex-start",
      border: "var(--hair) solid var(--ink-900)",
      borderRadius: "var(--radius-sm)",
      overflow: "hidden",
      ...style
    }
  }, rest), options.map((o, i) => {
    const v = o.value || o;
    const l = o.label || o;
    const on = v === active;
    return /*#__PURE__*/React.createElement("button", {
      key: v,
      type: "button",
      "aria-pressed": on,
      onClick: () => {
        setInner(v);
        onChange && onChange(v);
      },
      style: {
        padding: pad,
        border: 0,
        borderLeft: i ? "var(--hair) solid var(--ink-900)" : "0",
        background: on ? "var(--ink-900)" : "var(--surface-card)",
        color: on ? "var(--paper-000)" : "var(--ink-700)",
        cursor: "pointer",
        fontFamily: "var(--font-mono)",
        fontSize: "var(--text-2xs)",
        letterSpacing: "var(--tracking-label)",
        textTransform: "uppercase",
        whiteSpace: "nowrap",
        transition: "background var(--dur-fast) var(--ease-plot)"
      }
    }, l);
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function TabBar({
  items = [],
  value,
  onChange,
  style,
  ...rest
}) {
  const [inner, setInner] = React.useState(value || items[0] && items[0].id);
  const active = value !== undefined ? value : inner;
  return /*#__PURE__*/React.createElement("nav", _extends({
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(" + (items.length || 1) + ",1fr)",
      height: "var(--tabbar-h)",
      background: "var(--surface-card)",
      borderTop: "var(--hair) solid var(--border-default)",
      ...style
    }
  }, rest), items.map(it => {
    const on = it.id === active;
    return /*#__PURE__*/React.createElement("button", {
      key: it.id,
      type: "button",
      "aria-current": on,
      onClick: () => {
        setInner(it.id);
        onChange && onChange(it.id);
      },
      style: {
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: "var(--sp-2)",
        minHeight: "var(--touch-min)",
        border: 0,
        borderTop: "var(--rule-w) solid " + (on ? "var(--ink-900)" : "transparent"),
        marginTop: "-1px",
        background: "transparent",
        cursor: "pointer",
        color: on ? "var(--text-strong)" : "var(--text-faint)"
      }
    }, it.icon && /*#__PURE__*/React.createElement("img", {
      src: it.icon,
      width: "18",
      height: "18",
      alt: "",
      style: {
        opacity: on ? 1 : .55
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-sans)",
        fontSize: "var(--text-2xs)",
        fontWeight: "var(--weight-semibold)",
        letterSpacing: "var(--tracking-label)",
        textTransform: "uppercase"
      }
    }, it.label));
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Tabs.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Tabs({
  tabs = [],
  value,
  onChange,
  style,
  ...rest
}) {
  const [inner, setInner] = React.useState(value || tabs[0] && (tabs[0].id || tabs[0]));
  const active = value !== undefined ? value : inner;
  const pick = id => {
    setInner(id);
    onChange && onChange(id);
  };
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "tablist",
    style: {
      display: "flex",
      gap: "var(--sp-7)",
      borderBottom: "var(--hair) solid var(--rule-hair)",
      ...style
    }
  }, rest), tabs.map(t => {
    const id = t.id || t;
    const label = t.label || t;
    const on = id === active;
    return /*#__PURE__*/React.createElement("button", {
      key: id,
      role: "tab",
      "aria-selected": on,
      onClick: () => pick(id),
      style: {
        position: "relative",
        padding: "0 0 var(--sp-4)",
        border: 0,
        background: "transparent",
        cursor: "pointer",
        fontFamily: "var(--font-sans)",
        fontSize: "var(--text-xs)",
        fontWeight: "var(--weight-semibold)",
        letterSpacing: "var(--tracking-label)",
        textTransform: "uppercase",
        color: on ? "var(--text-strong)" : "var(--text-faint)",
        transition: "color var(--dur-fast) var(--ease-plot)"
      }
    }, label, t.count != null && /*#__PURE__*/React.createElement("span", {
      style: {
        marginLeft: "var(--sp-2)",
        fontFamily: "var(--font-mono)",
        fontWeight: 400,
        color: "var(--text-annotation)"
      }
    }, t.count), /*#__PURE__*/React.createElement("span", {
      "aria-hidden": "true",
      style: {
        position: "absolute",
        left: 0,
        right: 0,
        bottom: -1,
        height: "var(--rule-w)",
        background: on ? "var(--ink-900)" : "transparent"
      }
    }));
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/AnalysisScreen.jsx
try { (() => {
const {
  Tabs,
  SegmentedControl,
  StatBlock,
  FigureFrame,
  Sparkplot,
  DataTable,
  Callout,
  Equation,
  Card,
  Badge,
  IconButton
} = window.ApproximatelyScientificDesignSystem_b8396a;
function AnalysisScreen() {
  const [tab, setTab] = React.useState("analysis");
  const [range, setRange] = React.useState("Watts");
  const w = [180, 212, 240, 198, 265, 301, 254, 288, 231, 270, 310, 262, 240, 295, 281, 264, 302, 288, 240, 266, 290, 244];
  const hr = [122, 131, 140, 138, 148, 155, 151, 158, 149, 154, 161, 157, 150, 159, 158, 153, 162, 160, 151, 156, 163, 150];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement(StatusBar, null), /*#__PURE__*/React.createElement(AppHeader, {
    eyebrow: "RIDE 118 / TUE 04 AUG",
    title: "Threshold, approximately",
    right: /*#__PURE__*/React.createElement(IconButton, {
      label: "Share ride"
    }, /*#__PURE__*/React.createElement("img", {
      src: ico("share-2"),
      width: "16",
      alt: ""
    }))
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "var(--sp-5) var(--sp-6) 0"
    }
  }, /*#__PURE__*/React.createElement(Tabs, {
    value: tab,
    onChange: setTab,
    tabs: [{
      id: "analysis",
      label: "Analysis"
    }, {
      id: "splits",
      label: "Splits",
      count: 6
    }, {
      id: "methods",
      label: "Methods"
    }]
  })), /*#__PURE__*/React.createElement(Screen, {
    style: {
      padding: "var(--sp-6)"
    }
  }, tab === "analysis" && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(StatBlock, {
    label: "Est. avg power",
    value: "264",
    unit: "W",
    delta: "+9 W vs. Mar",
    size: "md",
    approx: true
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Distance",
    value: "41.2",
    unit: "km",
    tone: "blueprint",
    size: "md"
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Decoupling",
    value: "6.4",
    unit: "%",
    delta: "-1.1 pt",
    tone: "measure",
    size: "md"
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Elevation",
    value: "612",
    unit: "m",
    size: "md",
    approx: true
  })), /*#__PURE__*/React.createElement(SegmentedControl, {
    value: range,
    onChange: setRange,
    options: ["Watts", "Heart rate"]
  }), /*#__PURE__*/React.createElement(FigureFrame, {
    number: 2,
    caption: range === "Watts" ? "Estimated power vs. distance" : "Heart rate vs. distance",
    source: "1 Hz, smoothed 30 s",
    height: 150
  }, /*#__PURE__*/React.createElement(Sparkplot, {
    data: range === "Watts" ? w : hr,
    tone: range === "Watts" ? "plot3" : "plot1",
    height: "100%",
    baseline: true
  })), /*#__PURE__*/React.createElement(Callout, {
    tone: "result",
    title: "Result"
  }, "Aerobic decoupling fell to \u22486.4%. Either you are fitter, or the wind was kind. We cannot fully distinguish these.")), tab === "splits" && /*#__PURE__*/React.createElement(DataTable, {
    caption: "TABLE 1 \u2014 SEGMENT SPLITS",
    dense: true,
    columns: [{
      key: "seg",
      label: "Segment"
    }, {
      key: "km",
      label: "km",
      align: "right"
    }, {
      key: "w",
      label: "Avg W",
      align: "right"
    }, {
      key: "t",
      label: "Time",
      align: "right"
    }],
    rows: [{
      seg: "Neutral roll-out",
      km: "4.1",
      w: "172",
      t: "11:02"
    }, {
      seg: "Col de Rien",
      km: "6.8",
      w: "241",
      t: "18:04"
    }, {
      seg: "Flat, notional",
      km: "9.4",
      w: "198",
      t: "11:22"
    }, {
      seg: "The Wall, 12%",
      km: "1.2",
      w: "312",
      t: "4:41"
    }, {
      seg: "Descent",
      km: "7.9",
      w: "96",
      t: "9:18"
    }, {
      seg: "Run-in",
      km: "11.8",
      w: "224",
      t: "22:47"
    }]
  }), tab === "methods" && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(Equation, {
    number: 1,
    note: "Solved for P at each 1 s sample, then smoothed"
  }, "P \u2248 \xBD \u03C1 C", /*#__PURE__*/React.createElement("sub", null, "d"), "A v\xB3 + C", /*#__PURE__*/React.createElement("sub", null, "rr"), " m g v + m g v sin \u03B8"), /*#__PURE__*/React.createElement(Card, {
    label: "ASSUMPTIONS",
    title: "What we made up",
    footer: "Change these in Lab \u2192 Model inputs"
  }, /*#__PURE__*/React.createElement(DataTable, {
    dense: true,
    columns: [{
      key: "k",
      label: "Term"
    }, {
      key: "v",
      label: "Value",
      align: "right"
    }],
    rows: [{
      k: "CdA",
      v: "0.32 m²"
    }, {
      k: "Crr",
      v: "0.005"
    }, {
      k: "Mass (rider + bike)",
      v: "81.4 kg"
    }, {
      k: "Air density ρ",
      v: "1.225 kg/m³"
    }]
  })), /*#__PURE__*/React.createElement(Callout, {
    tone: "caution"
  }, "Barometric altitude drifts in heat. Gradient error above 10% may reach \xB12 pt."))));
}
Object.assign(window, {
  AnalysisScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/AnalysisScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/App.jsx
try { (() => {
const {
  TabBar
} = window.ApproximatelyScientificDesignSystem_b8396a;
function App() {
  const [tab, setTab] = React.useState("ride");
  const items = [{
    id: "ride",
    label: "Ride",
    icon: ico("bike")
  }, {
    id: "log",
    label: "Log",
    icon: ico("notebook-pen")
  }, {
    id: "analysis",
    label: "Analysis",
    icon: ico("chart-line")
  }, {
    id: "lab",
    label: "Lab",
    icon: ico("flask-conical")
  }];
  const S = {
    ride: RideScreen,
    log: LogScreen,
    analysis: AnalysisScreen,
    lab: LabScreen
  }[tab];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 390,
      height: 844,
      display: "flex",
      flexDirection: "column",
      overflow: "hidden",
      background: "var(--surface-page)",
      border: "var(--hair) solid var(--ink-900)",
      boxShadow: "var(--shadow-raise)"
    }
  }, /*#__PURE__*/React.createElement(S, null), /*#__PURE__*/React.createElement(TabBar, {
    items: items,
    value: tab,
    onChange: setTab
  }));
}
ReactDOM.createRoot(document.getElementById("root")).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/App.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Chrome.jsx
try { (() => {
const {
  Badge
} = window.ApproximatelyScientificDesignSystem_b8396a;
const ico = n => "https://unpkg.com/lucide-static@0.428.0/icons/" + n + ".svg";
function StatusBar({
  dark
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      padding: "10px 20px 4px",
      fontFamily: "var(--font-mono)",
      fontSize: 11,
      letterSpacing: ".04em",
      color: dark ? "var(--paper-000)" : "var(--ink-900)"
    }
  }, /*#__PURE__*/React.createElement("span", null, "09:41"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "flex",
      gap: 6,
      opacity: .8
    }
  }, /*#__PURE__*/React.createElement("span", null, "\u2248LTE"), /*#__PURE__*/React.createElement("span", null, "84%")));
}
function AppLockup() {
  return /*#__PURE__*/React.createElement("img", {
    src: "../../assets/wordmark.svg",
    width: "86",
    alt: "Imprecisely Accurate Instruments",
    style: {
      display: "block",
      marginBottom: "var(--sp-4)"
    }
  });
}
function AppHeader({
  eyebrow,
  title,
  right,
  dark,
  lockup
}) {
  return /*#__PURE__*/React.createElement("header", {
    style: {
      display: "flex",
      alignItems: "flex-end",
      justifyContent: "space-between",
      gap: "var(--sp-5)",
      padding: "var(--sp-4) var(--sp-6) var(--sp-5)",
      borderBottom: "var(--hair) solid var(--border-default)"
    }
  }, /*#__PURE__*/React.createElement("div", null, lockup && /*#__PURE__*/React.createElement(AppLockup, null), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: "var(--tracking-eyebrow)",
      textTransform: "uppercase",
      color: "var(--text-muted)"
    }
  }, eyebrow), /*#__PURE__*/React.createElement("h2", {
    style: {
      font: "var(--type-title)",
      fontSize: "var(--text-xl)",
      color: "var(--text-strong)",
      margin: "4px 0 0"
    }
  }, title)), right);
}
function Screen({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      ...style
    }
  }, children);
}
Object.assign(window, {
  StatusBar,
  AppHeader,
  AppLockup,
  Screen,
  ico
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Chrome.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/LabScreen.jsx
try { (() => {
const {
  Card,
  Switch,
  Input,
  Select,
  Equation,
  Badge,
  Button,
  Callout,
  ProgressMeter,
  Annotation
} = window.ApproximatelyScientificDesignSystem_b8396a;
function LabScreen() {
  const [overlay, setOverlay] = React.useState(true);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement(StatusBar, null), /*#__PURE__*/React.createElement(AppHeader, {
    eyebrow: "LAB / MODEL INPUTS",
    title: "Your assumptions",
    right: /*#__PURE__*/React.createElement(Badge, {
      tone: "blueprint"
    }, "v0.9")
  }), /*#__PURE__*/React.createElement(Screen, {
    style: {
      padding: "var(--sp-6)",
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(Card, {
    label: "ESTIMATOR",
    title: "Power model",
    subtitle: "Everything downstream depends on these four numbers."
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: "var(--sp-5)"
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Rider mass",
    defaultValue: "72.4",
    unit: "kg",
    mono: true
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Bike + kit",
    defaultValue: "9.0",
    unit: "kg",
    mono: true
  }), /*#__PURE__*/React.createElement(Input, {
    label: "CdA",
    defaultValue: "0.32",
    unit: "m\xB2",
    mono: true,
    hint: "Hoods, no bags"
  }), /*#__PURE__*/React.createElement(Input, {
    label: "Crr",
    defaultValue: "0.005",
    mono: true,
    hint: "28 mm, tarmac"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(Equation, {
    number: 2,
    display: false
  }, "P \u2248 \xBD \u03C1 C", /*#__PURE__*/React.createElement("sub", null, "d"), "A v\xB3 + C", /*#__PURE__*/React.createElement("sub", null, "rr"), " m g v"))), /*#__PURE__*/React.createElement(Card, {
    label: "THRESHOLD",
    title: "Estimated FTP",
    footer: "Recomputed nightly from your last 42 days."
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-5)"
    }
  }, /*#__PURE__*/React.createElement(ProgressMeter, {
    label: "Confidence",
    value: 68,
    max: 100,
    unit: "%",
    tone: "blueprint"
  }), /*#__PURE__*/React.createElement(Select, {
    label: "Estimation method",
    options: ["Coggan 95% of 20 min", "Skiba W&#39; balance", "Approximate (ours)"],
    hint: "Ours is not peer reviewed. Obviously."
  }), /*#__PURE__*/React.createElement(Annotation, {
    marker: "\xD8"
  }, "Last 6 rides had no maximal effort"))), /*#__PURE__*/React.createElement(Card, {
    label: "DISPLAY",
    title: "Live overlays"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-5)"
    }
  }, /*#__PURE__*/React.createElement(Switch, {
    label: "Show \xB1 error band on live power",
    checked: overlay,
    onChange: setOverlay
  }), /*#__PURE__*/React.createElement(Switch, {
    label: "Announce interval maths aloud"
  }), /*#__PURE__*/React.createElement(Switch, {
    label: "Round numbers for morale",
    defaultChecked: true
  }))), /*#__PURE__*/React.createElement(Callout, {
    tone: "method",
    title: "A word on precision"
  }, "We would rather be honestly approximate than precisely wrong. Every modelled number in this app carries a \u2248 and an error term."), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg",
    style: {
      justifyContent: "center"
    }
  }, "Recalculate everything")));
}
Object.assign(window, {
  LabScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/LabScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/LogScreen.jsx
try { (() => {
const {
  Card,
  Tag,
  Sparkplot,
  StatBlock,
  Badge,
  DataTable,
  IconButton
} = window.ApproximatelyScientificDesignSystem_b8396a;
const RIDES = [{
  d: "TUE 04 AUG",
  n: "Threshold, approximately",
  km: "41.2",
  w: "264",
  tags: ["Threshold", "Road"],
  trace: [180, 212, 240, 198, 265, 301, 254, 288, 231, 270, 310, 262]
}, {
  d: "SUN 02 AUG",
  n: "Four hours of guessing",
  km: "112.6",
  w: "196",
  tags: ["Endurance", "Gravel"],
  trace: [150, 168, 172, 160, 182, 175, 190, 166, 178, 184, 170, 158]
}, {
  d: "FRI 31 JUL",
  n: "Coffee ride, sub-threshold",
  km: "22.4",
  w: "148",
  tags: ["Recovery"],
  trace: [110, 124, 131, 118, 140, 128, 136, 120, 132, 126, 138, 122]
}, {
  d: "WED 29 JUL",
  n: "Six by four, allegedly",
  km: "38.9",
  w: "258",
  tags: ["Intervals", "Road"],
  trace: [190, 240, 300, 210, 305, 215, 298, 205, 310, 220, 295, 200]
}];
function LogScreen() {
  const [filter, setFilter] = React.useState("All");
  const tags = ["All", "Road", "Gravel", "Intervals", "Recovery"];
  const shown = filter === "All" ? RIDES : RIDES.filter(r => r.tags.includes(filter));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement(StatusBar, null), /*#__PURE__*/React.createElement(AppHeader, {
    lockup: true,
    eyebrow: "LOG / 118 RIDES",
    title: "Everything, recorded",
    right: /*#__PURE__*/React.createElement(IconButton, {
      label: "Search"
    }, /*#__PURE__*/React.createElement("img", {
      src: ico("search"),
      width: "16",
      alt: ""
    }))
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "var(--sp-3)",
      overflowX: "auto",
      padding: "var(--sp-5) var(--sp-6)",
      borderBottom: "var(--hair) solid var(--border-default)"
    }
  }, tags.map(t => /*#__PURE__*/React.createElement(Tag, {
    key: t,
    active: t === filter,
    onClick: () => setFilter(t)
  }, t))), /*#__PURE__*/React.createElement(Screen, {
    style: {
      padding: "var(--sp-6)",
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-5)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: "var(--sp-5)",
      paddingBottom: "var(--sp-5)",
      borderBottom: "var(--hair) solid var(--rule-hair)"
    }
  }, /*#__PURE__*/React.createElement(StatBlock, {
    label: "7-day",
    value: "215",
    unit: "km",
    size: "md"
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Load",
    value: "412",
    unit: "TSS",
    size: "md",
    approx: true
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Est. FTP",
    value: "268",
    unit: "W",
    tone: "measure",
    size: "md",
    approx: true
  })), shown.map((r, i) => /*#__PURE__*/React.createElement(Card, {
    key: r.n,
    label: r.d,
    title: r.n,
    footer: /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: "var(--sp-3)"
      }
    }, r.tags.map(t => /*#__PURE__*/React.createElement(Badge, {
      key: t
    }, t)))
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "auto 1fr",
      gap: "var(--sp-5)",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(DataTable, {
    dense: true,
    columns: [{
      key: "k",
      label: ""
    }, {
      key: "v",
      label: "",
      align: "right"
    }],
    rows: [{
      k: "km",
      v: r.km
    }, {
      k: "≈W",
      v: r.w
    }]
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      border: "var(--hair) solid var(--border-default)",
      backgroundImage: "var(--pattern-graph)",
      backgroundSize: "var(--pattern-tile)"
    }
  }, /*#__PURE__*/React.createElement(Sparkplot, {
    data: r.trace,
    tone: "plot" + (i % 4 + 2),
    height: 56
  })))))));
}
Object.assign(window, {
  LogScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/LogScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/RideScreen.jsx
try { (() => {
const {
  Readout,
  StatBlock,
  ProgressMeter,
  Sparkplot,
  Button,
  IconButton,
  Badge,
  Annotation
} = window.ApproximatelyScientificDesignSystem_b8396a;
function RideScreen() {
  const [running, setRunning] = React.useState(true);
  const [t, setT] = React.useState(2531);
  const [power, setPower] = React.useState(284);
  React.useEffect(() => {
    if (!running) return;
    const id = setInterval(() => setPower(260 + Math.round(Math.random() * 46)), 1400);
    return () => clearInterval(id);
  }, [running]);
  React.useEffect(() => {
    if (!running) return;
    const id = setInterval(() => setT(v => v + 1), 1000);
    return () => clearInterval(id);
  }, [running]);
  const mmss = s => String(Math.floor(s / 3600)) + ":" + String(Math.floor(s % 3600 / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
  const trace = [180, 212, 240, 198, 265, 301, 254, 288, 231, 270, 310, 262, 240, 295, 281, 264, 302, 288];
  return /*#__PURE__*/React.createElement("div", {
    className: "as-blueprint",
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement(StatusBar, {
    dark: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "var(--sp-4) var(--sp-6)",
      borderBottom: "var(--hair) solid var(--border-default)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-muted)"
    }
  }, "SESSION 12 / INTERVAL 4 OF 6"), /*#__PURE__*/React.createElement(Badge, {
    tone: "measure"
  }, running ? "REC" : "PAUSED")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "var(--sp-6)",
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-7)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-3)"
    }
  }, /*#__PURE__*/React.createElement(Readout, {
    value: power,
    digits: 3,
    decimals: 0,
    unit: "Watts",
    label: "Estimated power",
    approx: true
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: 12,
      color: "var(--text-muted)"
    }
  }, "\xB111 W \xB7 modelled from speed, mass, gradient")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: "var(--sp-5)",
      borderTop: "var(--hair) solid var(--border-default)",
      borderBottom: "var(--hair) solid var(--border-default)",
      padding: "var(--sp-5) 0"
    }
  }, /*#__PURE__*/React.createElement(StatBlock, {
    label: "Elapsed",
    value: mmss(t),
    size: "md"
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Cadence",
    value: "91",
    unit: "rpm",
    size: "md"
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Grade",
    value: "4.2",
    unit: "%",
    tone: "measure",
    size: "md"
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Annotation, {
    marker: "A"
  }, "Last 3 min, 1 Hz samples"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: "var(--sp-4)",
      border: "var(--hair) solid var(--border-default)",
      backgroundImage: "var(--pattern-graph)",
      backgroundSize: "var(--pattern-tile)"
    }
  }, /*#__PURE__*/React.createElement(Sparkplot, {
    data: trace,
    tone: "plot5",
    height: 96,
    strokeWidth: 2
  }))), /*#__PURE__*/React.createElement(ProgressMeter, {
    label: "Interval 4 target",
    value: 284,
    max: 320,
    unit: "W",
    tone: "measure",
    ticks: 8
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "var(--sp-4)",
      padding: "var(--sp-5) var(--sp-6)",
      borderTop: "var(--hair) solid var(--border-default)",
      background: "var(--surface-card)"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: running ? "secondary" : "measure",
    size: "lg",
    onClick: () => setRunning(!running),
    style: {
      flex: 1,
      justifyContent: "center"
    }
  }, running ? "Pause" : "Resume"), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg",
    style: {
      flex: 1,
      justifyContent: "center"
    }
  }, "Lap"), /*#__PURE__*/React.createElement(IconButton, {
    label: "Ride settings",
    size: "lg",
    variant: "ghost"
  }, /*#__PURE__*/React.createElement("img", {
    src: ico("sliders-horizontal"),
    width: "18",
    alt: "",
    style: {
      filter: "invert(1)"
    }
  }))));
}
Object.assign(window, {
  RideScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/RideScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/Hero.jsx
try { (() => {
const {
  Button,
  Badge,
  Sparkplot,
  Equation,
  Annotation,
  StatBlock
} = window.ApproximatelyScientificDesignSystem_b8396a;
function Hero() {
  const trace = [180, 212, 240, 198, 265, 301, 254, 288, 231, 270, 310, 262, 240, 295, 281, 264, 302, 288, 240, 266, 290, 244, 272, 300];
  return /*#__PURE__*/React.createElement("section", {
    id: "top",
    style: {
      position: "relative",
      padding: "var(--sp-12) var(--sp-8) var(--sp-11)",
      backgroundColor: "var(--paper-000)",
      borderBottom: "var(--hair) solid var(--border-default)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "var(--container-lg)",
      margin: "0 auto",
      display: "grid",
      gridTemplateColumns: "1.15fr .85fr",
      gap: "var(--sp-10)",
      alignItems: "end"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: "var(--sp-4)",
      marginBottom: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "blueprint"
  }, "EST. 2019"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)"
    }
  }, "SIX APPS \xB7 ONE METHOD \xB7 NO PEER REVIEW")), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: "var(--type-display)",
      fontSize: "var(--text-5xl)",
      color: "var(--text-strong)",
      maxWidth: "18ch"
    }
  }, "Numbers you can nearly trust."), /*#__PURE__*/React.createElement("p", {
    style: {
      font: "var(--type-body-serif)",
      color: "var(--text-muted)",
      maxWidth: "46ch",
      margin: "var(--sp-6) 0 var(--sp-8)"
    }
  }, "We build cycling apps that model what they cannot measure, then tell you exactly how wrong they might be. The error bar is the product."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "var(--sp-5)",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg"
  }, "Get the app"), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    size: "lg"
  }, "Read the method")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "var(--sp-9)",
      marginTop: "var(--sp-9)",
      paddingTop: "var(--sp-6)",
      borderTop: "var(--hair) solid var(--rule-hair)"
    }
  }, /*#__PURE__*/React.createElement(StatBlock, {
    label: "Rides modelled",
    value: "1.4",
    unit: "M",
    approx: true
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Median error",
    value: "\xB14",
    unit: "%",
    tone: "measure"
  }), /*#__PURE__*/React.createElement(StatBlock, {
    label: "Assumptions",
    value: "17",
    tone: "blueprint"
  }))), /*#__PURE__*/React.createElement("figure", {
    style: {
      margin: 0,
      background: "var(--surface-card)",
      border: "var(--hair) solid var(--ink-900)",
      boxShadow: "var(--shadow-raise)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "var(--sp-5) var(--sp-6)",
      borderBottom: "var(--hair) solid var(--rule-hair)",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "baseline"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)"
    }
  }, "FIG. 01"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)"
    }
  }, "est. power, ride 118")), /*#__PURE__*/React.createElement("div", {
    style: {
      backgroundImage: "var(--pattern-graph)",
      backgroundSize: "var(--pattern-tile)"
    }
  }, /*#__PURE__*/React.createElement(Sparkplot, {
    data: trace,
    tone: "plot3",
    height: 180,
    baseline: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "var(--sp-5) var(--sp-6)",
      borderTop: "var(--hair) solid var(--rule-hair)",
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-4)"
    }
  }, /*#__PURE__*/React.createElement(Equation, {
    display: false,
    number: 1
  }, "P \u2248 \xBD \u03C1 C", /*#__PURE__*/React.createElement("sub", null, "d"), "A v\xB3 + C", /*#__PURE__*/React.createElement("sub", null, "rr"), " m g v"), /*#__PURE__*/React.createElement(Annotation, {
    marker: "A"
  }, "Solved per second, smoothed over 30 s")))));
}
Object.assign(window, {
  Hero
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/Hero.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/Sections.jsx
try { (() => {
const {
  Card,
  Callout,
  Equation,
  DataTable,
  Sparkplot,
  Tag,
  Badge,
  SegmentedControl,
  StatBlock,
  Input,
  Button,
  FigureFrame
} = window.ApproximatelyScientificDesignSystem_b8396a;
const APPS = [{
  n: "Watt, Approximately",
  d: "Power without a power meter. Speed, mass and gradient in; a number and an error bar out.",
  tags: ["iOS", "Android"],
  trace: [180, 212, 240, 198, 265, 301, 254, 288, 231, 270, 310, 262]
}, {
  n: "Gradient Anxiety",
  d: "Tells you how steep the next 400 m is, and how much that should worry you.",
  tags: ["iOS"],
  trace: [3, 5, 9, 12, 8, 14, 11, 6, 4, 9, 13, 7]
}, {
  n: "Coffee Stop Solver",
  d: "Optimises café placement against distance, daylight and willpower decay.",
  tags: ["Web"],
  trace: [100, 92, 84, 70, 62, 55, 48, 40, 33, 28, 20, 14]
}, {
  n: "Tailwind Denial",
  d: "Estimates how much of your PR was the wind. Usually more than you would like.",
  tags: ["iOS", "Web"],
  trace: [8, 11, 7, 14, 9, 16, 12, 10, 15, 8, 13, 11]
}, {
  n: "Chain Line Purist",
  d: "Cross-chaining loss, quantified to a precision nobody requested.",
  tags: ["Web"],
  trace: [1, 2, 2, 3, 5, 4, 6, 8, 7, 9, 11, 10]
}, {
  n: "Recovery, Allegedly",
  d: "Sleep and load in, a confidence interval out. Never a single readiness score.",
  tags: ["Android"],
  trace: [60, 64, 58, 70, 66, 74, 71, 68, 76, 72, 80, 77]
}];
function AppsSection() {
  const [plat, setPlat] = React.useState("All");
  const shown = plat === "All" ? APPS : APPS.filter(a => a.tags.includes(plat));
  return /*#__PURE__*/React.createElement("section", {
    id: "apps",
    style: {
      padding: "var(--sp-11) var(--sp-8)",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "var(--container-lg)",
      margin: "0 auto"
    }
  }, /*#__PURE__*/React.createElement(SectionHead, {
    number: "01",
    eyebrow: "THE CATALOGUE",
    title: "Six apps, all of them approximately right",
    lede: "Each one models a quantity that is expensive to measure, and is honest about the residual."
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      marginBottom: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(SegmentedControl, {
    value: plat,
    onChange: setPlat,
    options: ["All", "iOS", "Android", "Web"]
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)"
    }
  }, "n = ", shown.length)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(3,1fr)",
      gap: "var(--sp-6)"
    }
  }, shown.map((a, i) => /*#__PURE__*/React.createElement(Card, {
    key: a.n,
    label: "APP " + String(i + 1).padStart(2, "0"),
    title: a.n,
    footer: /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        gap: "var(--sp-3)"
      }
    }, a.tags.map(t => /*#__PURE__*/React.createElement(Badge, {
      key: t,
      tone: "neutral"
    }, t)))
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      color: "var(--text-muted)",
      margin: "0 0 var(--sp-5)"
    }
  }, a.d), /*#__PURE__*/React.createElement("div", {
    style: {
      border: "var(--hair) solid var(--border-default)",
      backgroundImage: "var(--pattern-graph)",
      backgroundSize: "var(--pattern-tile)"
    }
  }, /*#__PURE__*/React.createElement(Sparkplot, {
    data: a.trace,
    tone: "plot" + (i + 1),
    height: 64
  })))))));
}
function MethodSection() {
  return /*#__PURE__*/React.createElement("section", {
    id: "method",
    style: {
      padding: "var(--sp-11) var(--sp-8)",
      backgroundColor: "var(--paper-000)",
      borderTop: "var(--hair) solid var(--border-default)",
      borderBottom: "var(--hair) solid var(--border-default)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "var(--container-lg)",
      margin: "0 auto"
    }
  }, /*#__PURE__*/React.createElement(SectionHead, {
    number: "02",
    eyebrow: "THE METHOD",
    title: "Model it, bound it, show the bound",
    lede: "Three rules govern every number we ship."
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: "var(--sp-9)",
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(Callout, {
    tone: "method",
    label: "RULE 01",
    title: "Every estimate carries \u2248"
  }, "If we did not measure it, the number wears a tilde. No exceptions, including on the marketing site."), /*#__PURE__*/React.createElement(Callout, {
    tone: "method",
    label: "RULE 02",
    title: "Publish the assumptions"
  }, "CdA, Crr, mass, air density. All editable, all visible, all wrong in interesting ways."), /*#__PURE__*/React.createElement(Callout, {
    tone: "method",
    label: "RULE 03",
    title: "Never a single score"
  }, "Readiness, form, fitness \u2014 always an interval, never one confident integer.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-6)"
    }
  }, /*#__PURE__*/React.createElement(Equation, {
    number: 2,
    note: "The residual \u03B5 is what we spend our time on"
  }, "y = f(x) + \u03B5"), /*#__PURE__*/React.createElement(FigureFrame, {
    number: 3,
    caption: "Estimated vs. measured power, 412 paired rides",
    source: "mean absolute error \u22484.1%",
    height: 170,
    pattern: "graph"
  }, /*#__PURE__*/React.createElement(Sparkplot, {
    data: [12, 9, 14, 8, 11, 6, 9, 4, 7, 3, 6, 2, 5, 3, 4, 2, 3, 2, 2, 1],
    tone: "plot3",
    height: "100%",
    baseline: true
  })), /*#__PURE__*/React.createElement(DataTable, {
    caption: "TABLE 2 \u2014 WHERE WE ARE WRONG",
    dense: true,
    columns: [{
      key: "c",
      label: "Condition"
    }, {
      key: "e",
      label: "Median error",
      align: "right"
    }],
    rows: [{
      c: "Flat, still air",
      e: "±2.1%"
    }, {
      c: "Rolling, gusting",
      e: "±5.4%"
    }, {
      c: "Climb > 10%",
      e: "±7.8%"
    }, {
      c: "Wet gravel",
      e: "±11.2%"
    }]
  })))));
}
function PapersSection() {
  return /*#__PURE__*/React.createElement("section", {
    id: "papers",
    style: {
      padding: "var(--sp-11) var(--sp-8)",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "var(--container-md)",
      margin: "0 auto"
    }
  }, /*#__PURE__*/React.createElement(SectionHead, {
    number: "03",
    eyebrow: "PAPERS, LOOSELY",
    title: "Notes we wrote instead of shipping features"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column"
    }
  }, [["On the futility of readiness scores", "Mar 2026", "4 min"], ["Estimating CdA from a single descent", "Jan 2026", "9 min"], ["Coffee stop placement as a constrained optimisation", "Nov 2025", "12 min"], ["Why your PR was mostly weather", "Aug 2025", "6 min"]].map(([t, d, r], i) => /*#__PURE__*/React.createElement("a", {
    key: t,
    href: "#papers",
    onClick: e => e.preventDefault(),
    style: {
      display: "grid",
      gridTemplateColumns: "auto 1fr auto auto",
      gap: "var(--sp-6)",
      alignItems: "baseline",
      padding: "var(--sp-5) 0",
      borderTop: "var(--hair) solid var(--rule-hair)",
      borderBottom: i === 3 ? "var(--hair) solid var(--rule-hair)" : "none"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-label)",
      color: "var(--text-annotation)"
    }
  }, String(i + 1).padStart(2, "0")), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-display)",
      fontSize: "var(--text-md)",
      color: "var(--text-strong)"
    }
  }, t), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)"
    }
  }, d), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-muted)"
    }
  }, r))))));
}
function SignupSection() {
  const [sent, setSent] = React.useState(false);
  return /*#__PURE__*/React.createElement("section", {
    id: "about",
    className: "as-blueprint",
    style: {
      padding: "var(--sp-11) var(--sp-8)",
      background: "var(--surface-page)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "var(--container-md)",
      margin: "0 auto",
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: "var(--sp-9)",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: "var(--tracking-eyebrow)",
      textTransform: "uppercase",
      color: "var(--text-muted)",
      marginBottom: "var(--sp-5)"
    }
  }, "THE APPENDIX / MONTHLY"), /*#__PURE__*/React.createElement("h2", {
    style: {
      font: "var(--type-title)",
      fontSize: "var(--text-2xl)",
      color: "var(--text-strong)"
    }
  }, "One email a month, mostly footnotes."), /*#__PURE__*/React.createElement("p", {
    style: {
      font: "var(--type-body-serif)",
      color: "var(--text-body)",
      maxWidth: "40ch",
      marginTop: "var(--sp-5)"
    }
  }, "Method changes, error-bar improvements, and the occasional retraction.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-5)",
      padding: "var(--sp-7)",
      background: "var(--surface-card)",
      border: "var(--hair) solid var(--border-strong)"
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Email",
    placeholder: "rider@example.com",
    hint: "No tracking pixels. We can barely track power."
  }), /*#__PURE__*/React.createElement(Button, {
    variant: "measure",
    size: "lg",
    onClick: () => setSent(true),
    style: {
      justifyContent: "center"
    }
  }, sent ? "Subscribed ≈ probably" : "Subscribe"))));
}
function SiteFooter() {
  return /*#__PURE__*/React.createElement("footer", {
    style: {
      padding: "var(--sp-9) var(--sp-8)",
      background: "var(--paper-000)",
      borderTop: "var(--rule-w) solid var(--ink-900)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "var(--container-lg)",
      margin: "0 auto",
      display: "grid",
      gridTemplateColumns: "1.4fr 1fr 1fr 1fr",
      gap: "var(--sp-8)"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/wordmark-caliper.svg",
    width: "340",
    alt: "Imprecisely Accurate Instruments",
    style: {
      color: "var(--ink-900)"
    }
  }), /*#__PURE__*/React.createElement("p", {
    style: {
      font: "var(--type-data)",
      fontSize: "var(--text-xs)",
      color: "var(--text-faint)",
      marginTop: "var(--sp-5)",
      maxWidth: "32ch"
    }
  }, "Imprecisely Accurate Instruments Ltd. Nothing here is medical, legal or particularly rigorous advice.")), [["APPS", ["Watt, Approximately", "Gradient Anxiety", "Coffee Stop Solver"]], ["METHOD", ["The three rules", "Error tables", "Changelog"]], ["ELSEWHERE", ["Repository", "Mastodon", "Contact"]]].map(([h, items]) => /*#__PURE__*/React.createElement("div", {
    key: h
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: "var(--text-annotation)",
      marginBottom: "var(--sp-5)"
    }
  }, h), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: "var(--sp-4)"
    }
  }, items.map(i => /*#__PURE__*/React.createElement("a", {
    key: i,
    href: "#top",
    onClick: e => e.preventDefault(),
    style: {
      font: "var(--type-body)",
      fontSize: "var(--text-sm)",
      border: 0,
      color: "var(--text-body)"
    }
  }, i)))))));
}
Object.assign(window, {
  AppsSection,
  MethodSection,
  PapersSection,
  SignupSection,
  SiteFooter
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/Sections.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/Site.jsx
try { (() => {
function Site() {
  const [active, setActive] = React.useState("top");
  const nav = id => {
    setActive(id);
    const el = document.getElementById(id);
    if (el) window.scrollTo({
      top: el.offsetTop - 56,
      behavior: "smooth"
    });
  };
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(SiteHeader, {
    active: active,
    onNav: nav
  }), /*#__PURE__*/React.createElement(Hero, null), /*#__PURE__*/React.createElement(AppsSection, null), /*#__PURE__*/React.createElement(MethodSection, null), /*#__PURE__*/React.createElement(PapersSection, null), /*#__PURE__*/React.createElement(SignupSection, null), /*#__PURE__*/React.createElement(SiteFooter, null));
}
ReactDOM.createRoot(document.getElementById("root")).render(/*#__PURE__*/React.createElement(Site, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/Site.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/SiteChrome.jsx
try { (() => {
const {
  Button,
  IconButton
} = window.ApproximatelyScientificDesignSystem_b8396a;
const wico = n => "https://unpkg.com/lucide-static@0.428.0/icons/" + n + ".svg";
function SiteHeader({
  active,
  onNav
}) {
  const links = [["apps", "Apps"], ["method", "Method"], ["papers", "Papers"], ["about", "About"]];
  return /*#__PURE__*/React.createElement("header", {
    style: {
      position: "sticky",
      top: 0,
      zIndex: 20,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: "var(--sp-7)",
      height: "var(--nav-h)",
      padding: "0 var(--sp-8)",
      background: "var(--veil)",
      backdropFilter: "var(--blur-sheet)",
      borderBottom: "var(--hair) solid var(--border-default)"
    }
  }, /*#__PURE__*/React.createElement("a", {
    href: "#top",
    onClick: e => {
      e.preventDefault();
      onNav("top");
    },
    style: {
      display: "flex",
      alignItems: "center",
      gap: "var(--sp-2)",
      border: 0
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/wordmark-caliper-sm.svg",
    width: "212",
    alt: "Imprecisely Accurate Instruments",
    style: {
      color: "var(--ink-900)",
      display: "block"
    }
  })), /*#__PURE__*/React.createElement("nav", {
    style: {
      display: "flex",
      gap: "var(--sp-7)"
    }
  }, links.map(([id, label]) => /*#__PURE__*/React.createElement("a", {
    key: id,
    href: "#" + id,
    onClick: e => {
      e.preventDefault();
      onNav(id);
    },
    style: {
      border: 0,
      font: "var(--type-eyebrow)",
      letterSpacing: "var(--tracking-label)",
      textTransform: "uppercase",
      color: active === id ? "var(--text-strong)" : "var(--text-muted)",
      borderBottom: "var(--rule-w) solid " + (active === id ? "var(--ink-900)" : "transparent"),
      paddingBottom: 2
    }
  }, label))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: "var(--sp-4)",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    label: "Repository",
    variant: "ghost"
  }, /*#__PURE__*/React.createElement("img", {
    src: wico("github"),
    width: "16",
    alt: ""
  })), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "sm"
  }, "Get the app")));
}
function SectionHead({
  number,
  eyebrow,
  title,
  lede
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "auto 1fr",
      gap: "var(--sp-7)",
      alignItems: "start",
      paddingTop: "var(--sp-6)",
      borderTop: "var(--rule-w) solid var(--ink-900)",
      marginBottom: "var(--sp-8)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-label)",
      letterSpacing: "var(--tracking-label)",
      color: "var(--text-annotation)"
    }
  }, number), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "var(--type-eyebrow)",
      letterSpacing: "var(--tracking-eyebrow)",
      textTransform: "uppercase",
      color: "var(--text-muted)",
      marginBottom: "var(--sp-4)"
    }
  }, eyebrow), /*#__PURE__*/React.createElement("h2", {
    style: {
      font: "var(--type-title)",
      fontSize: "var(--text-2xl)",
      color: "var(--text-strong)",
      maxWidth: "22ch"
    }
  }, title), lede && /*#__PURE__*/React.createElement("p", {
    style: {
      font: "var(--type-body-serif)",
      color: "var(--text-muted)",
      maxWidth: "58ch",
      margin: "var(--sp-5) 0 0"
    }
  }, lede)));
}
Object.assign(window, {
  SiteHeader,
  SectionHead,
  wico
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/SiteChrome.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Annotation = __ds_scope.Annotation;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.DataTable = __ds_scope.DataTable;

__ds_ns.Equation = __ds_scope.Equation;

__ds_ns.FigureFrame = __ds_scope.FigureFrame;

__ds_ns.Readout = __ds_scope.Readout;

__ds_ns.Sparkplot = __ds_scope.Sparkplot;

__ds_ns.StatBlock = __ds_scope.StatBlock;

__ds_ns.Callout = __ds_scope.Callout;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.ProgressMeter = __ds_scope.ProgressMeter;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.Tabs = __ds_scope.Tabs;

})();
