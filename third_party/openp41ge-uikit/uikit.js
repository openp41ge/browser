var __defProp = Object.defineProperty;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
/**
 * @license
 * Copyright 2019 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
var _a;
const t$3 = globalThis, e$3 = t$3.ShadowRoot && (void 0 === t$3.ShadyCSS || t$3.ShadyCSS.nativeShadow) && "adoptedStyleSheets" in Document.prototype && "replace" in CSSStyleSheet.prototype, s$2 = Symbol(), o$4 = /* @__PURE__ */ new WeakMap();
let n$3 = class n {
  constructor(t2, e2, o2) {
    if (this._$cssResult$ = true, o2 !== s$2) throw Error("CSSResult is not constructable. Use `unsafeCSS` or `css` instead.");
    this.cssText = t2, this.t = e2;
  }
  get styleSheet() {
    let t2 = this.o;
    const s2 = this.t;
    if (e$3 && void 0 === t2) {
      const e2 = void 0 !== s2 && 1 === s2.length;
      e2 && (t2 = o$4.get(s2)), void 0 === t2 && ((this.o = t2 = new CSSStyleSheet()).replaceSync(this.cssText), e2 && o$4.set(s2, t2));
    }
    return t2;
  }
  toString() {
    return this.cssText;
  }
};
const r$5 = (t2) => new n$3("string" == typeof t2 ? t2 : t2 + "", void 0, s$2), i$4 = (t2, ...e2) => {
  const o2 = 1 === t2.length ? t2[0] : e2.reduce((e3, s2, o3) => e3 + ((t3) => {
    if (true === t3._$cssResult$) return t3.cssText;
    if ("number" == typeof t3) return t3;
    throw Error("Value passed to 'css' function must be a 'css' function result: " + t3 + ". Use 'unsafeCSS' to pass non-literal values, but take care to ensure page security.");
  })(s2) + t2[o3 + 1], t2[0]);
  return new n$3(o2, t2, s$2);
}, S$1 = (s2, o2) => {
  if (e$3) s2.adoptedStyleSheets = o2.map((t2) => t2 instanceof CSSStyleSheet ? t2 : t2.styleSheet);
  else for (const e2 of o2) {
    const o3 = document.createElement("style"), n3 = t$3.litNonce;
    void 0 !== n3 && o3.setAttribute("nonce", n3), o3.textContent = e2.cssText, s2.appendChild(o3);
  }
}, c$2 = e$3 ? (t2) => t2 : (t2) => t2 instanceof CSSStyleSheet ? ((t3) => {
  let e2 = "";
  for (const s2 of t3.cssRules) e2 += s2.cssText;
  return r$5(e2);
})(t2) : t2;
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const { is: i$3, defineProperty: e$2, getOwnPropertyDescriptor: h$1, getOwnPropertyNames: r$4, getOwnPropertySymbols: o$3, getPrototypeOf: n$2 } = Object, a$1 = globalThis, c$1 = a$1.trustedTypes, l$2 = c$1 ? c$1.emptyScript : "", p$2 = a$1.reactiveElementPolyfillSupport, d$1 = (t2, s2) => t2, u$1 = { toAttribute(t2, s2) {
  switch (s2) {
    case Boolean:
      t2 = t2 ? l$2 : null;
      break;
    case Object:
    case Array:
      t2 = null == t2 ? t2 : JSON.stringify(t2);
  }
  return t2;
}, fromAttribute(t2, s2) {
  let i3 = t2;
  switch (s2) {
    case Boolean:
      i3 = null !== t2;
      break;
    case Number:
      i3 = null === t2 ? null : Number(t2);
      break;
    case Object:
    case Array:
      try {
        i3 = JSON.parse(t2);
      } catch (t3) {
        i3 = null;
      }
  }
  return i3;
} }, f$1 = (t2, s2) => !i$3(t2, s2), b$1 = { attribute: true, type: String, converter: u$1, reflect: false, useDefault: false, hasChanged: f$1 };
Symbol.metadata ?? (Symbol.metadata = Symbol("metadata")), a$1.litPropertyMetadata ?? (a$1.litPropertyMetadata = /* @__PURE__ */ new WeakMap());
let y$1 = class y extends HTMLElement {
  static addInitializer(t2) {
    this._$Ei(), (this.l ?? (this.l = [])).push(t2);
  }
  static get observedAttributes() {
    return this.finalize(), this._$Eh && [...this._$Eh.keys()];
  }
  static createProperty(t2, s2 = b$1) {
    if (s2.state && (s2.attribute = false), this._$Ei(), this.prototype.hasOwnProperty(t2) && ((s2 = Object.create(s2)).wrapped = true), this.elementProperties.set(t2, s2), !s2.noAccessor) {
      const i3 = Symbol(), h2 = this.getPropertyDescriptor(t2, i3, s2);
      void 0 !== h2 && e$2(this.prototype, t2, h2);
    }
  }
  static getPropertyDescriptor(t2, s2, i3) {
    const { get: e2, set: r2 } = h$1(this.prototype, t2) ?? { get() {
      return this[s2];
    }, set(t3) {
      this[s2] = t3;
    } };
    return { get: e2, set(s3) {
      const h2 = e2 == null ? void 0 : e2.call(this);
      r2 == null ? void 0 : r2.call(this, s3), this.requestUpdate(t2, h2, i3);
    }, configurable: true, enumerable: true };
  }
  static getPropertyOptions(t2) {
    return this.elementProperties.get(t2) ?? b$1;
  }
  static _$Ei() {
    if (this.hasOwnProperty(d$1("elementProperties"))) return;
    const t2 = n$2(this);
    t2.finalize(), void 0 !== t2.l && (this.l = [...t2.l]), this.elementProperties = new Map(t2.elementProperties);
  }
  static finalize() {
    if (this.hasOwnProperty(d$1("finalized"))) return;
    if (this.finalized = true, this._$Ei(), this.hasOwnProperty(d$1("properties"))) {
      const t3 = this.properties, s2 = [...r$4(t3), ...o$3(t3)];
      for (const i3 of s2) this.createProperty(i3, t3[i3]);
    }
    const t2 = this[Symbol.metadata];
    if (null !== t2) {
      const s2 = litPropertyMetadata.get(t2);
      if (void 0 !== s2) for (const [t3, i3] of s2) this.elementProperties.set(t3, i3);
    }
    this._$Eh = /* @__PURE__ */ new Map();
    for (const [t3, s2] of this.elementProperties) {
      const i3 = this._$Eu(t3, s2);
      void 0 !== i3 && this._$Eh.set(i3, t3);
    }
    this.elementStyles = this.finalizeStyles(this.styles);
  }
  static finalizeStyles(s2) {
    const i3 = [];
    if (Array.isArray(s2)) {
      const e2 = new Set(s2.flat(1 / 0).reverse());
      for (const s3 of e2) i3.unshift(c$2(s3));
    } else void 0 !== s2 && i3.push(c$2(s2));
    return i3;
  }
  static _$Eu(t2, s2) {
    const i3 = s2.attribute;
    return false === i3 ? void 0 : "string" == typeof i3 ? i3 : "string" == typeof t2 ? t2.toLowerCase() : void 0;
  }
  constructor() {
    super(), this._$Ep = void 0, this.isUpdatePending = false, this.hasUpdated = false, this._$Em = null, this._$Ev();
  }
  _$Ev() {
    var _a2;
    this._$ES = new Promise((t2) => this.enableUpdating = t2), this._$AL = /* @__PURE__ */ new Map(), this._$E_(), this.requestUpdate(), (_a2 = this.constructor.l) == null ? void 0 : _a2.forEach((t2) => t2(this));
  }
  addController(t2) {
    var _a2;
    (this._$EO ?? (this._$EO = /* @__PURE__ */ new Set())).add(t2), void 0 !== this.renderRoot && this.isConnected && ((_a2 = t2.hostConnected) == null ? void 0 : _a2.call(t2));
  }
  removeController(t2) {
    var _a2;
    (_a2 = this._$EO) == null ? void 0 : _a2.delete(t2);
  }
  _$E_() {
    const t2 = /* @__PURE__ */ new Map(), s2 = this.constructor.elementProperties;
    for (const i3 of s2.keys()) this.hasOwnProperty(i3) && (t2.set(i3, this[i3]), delete this[i3]);
    t2.size > 0 && (this._$Ep = t2);
  }
  createRenderRoot() {
    const t2 = this.shadowRoot ?? this.attachShadow(this.constructor.shadowRootOptions);
    return S$1(t2, this.constructor.elementStyles), t2;
  }
  connectedCallback() {
    var _a2;
    this.renderRoot ?? (this.renderRoot = this.createRenderRoot()), this.enableUpdating(true), (_a2 = this._$EO) == null ? void 0 : _a2.forEach((t2) => {
      var _a3;
      return (_a3 = t2.hostConnected) == null ? void 0 : _a3.call(t2);
    });
  }
  enableUpdating(t2) {
  }
  disconnectedCallback() {
    var _a2;
    (_a2 = this._$EO) == null ? void 0 : _a2.forEach((t2) => {
      var _a3;
      return (_a3 = t2.hostDisconnected) == null ? void 0 : _a3.call(t2);
    });
  }
  attributeChangedCallback(t2, s2, i3) {
    this._$AK(t2, i3);
  }
  _$ET(t2, s2) {
    var _a2;
    const i3 = this.constructor.elementProperties.get(t2), e2 = this.constructor._$Eu(t2, i3);
    if (void 0 !== e2 && true === i3.reflect) {
      const h2 = (void 0 !== ((_a2 = i3.converter) == null ? void 0 : _a2.toAttribute) ? i3.converter : u$1).toAttribute(s2, i3.type);
      this._$Em = t2, null == h2 ? this.removeAttribute(e2) : this.setAttribute(e2, h2), this._$Em = null;
    }
  }
  _$AK(t2, s2) {
    var _a2, _b;
    const i3 = this.constructor, e2 = i3._$Eh.get(t2);
    if (void 0 !== e2 && this._$Em !== e2) {
      const t3 = i3.getPropertyOptions(e2), h2 = "function" == typeof t3.converter ? { fromAttribute: t3.converter } : void 0 !== ((_a2 = t3.converter) == null ? void 0 : _a2.fromAttribute) ? t3.converter : u$1;
      this._$Em = e2;
      const r2 = h2.fromAttribute(s2, t3.type);
      this[e2] = r2 ?? ((_b = this._$Ej) == null ? void 0 : _b.get(e2)) ?? r2, this._$Em = null;
    }
  }
  requestUpdate(t2, s2, i3, e2 = false, h2) {
    var _a2;
    if (void 0 !== t2) {
      const r2 = this.constructor;
      if (false === e2 && (h2 = this[t2]), i3 ?? (i3 = r2.getPropertyOptions(t2)), !((i3.hasChanged ?? f$1)(h2, s2) || i3.useDefault && i3.reflect && h2 === ((_a2 = this._$Ej) == null ? void 0 : _a2.get(t2)) && !this.hasAttribute(r2._$Eu(t2, i3)))) return;
      this.C(t2, s2, i3);
    }
    false === this.isUpdatePending && (this._$ES = this._$EP());
  }
  C(t2, s2, { useDefault: i3, reflect: e2, wrapped: h2 }, r2) {
    i3 && !(this._$Ej ?? (this._$Ej = /* @__PURE__ */ new Map())).has(t2) && (this._$Ej.set(t2, r2 ?? s2 ?? this[t2]), true !== h2 || void 0 !== r2) || (this._$AL.has(t2) || (this.hasUpdated || i3 || (s2 = void 0), this._$AL.set(t2, s2)), true === e2 && this._$Em !== t2 && (this._$Eq ?? (this._$Eq = /* @__PURE__ */ new Set())).add(t2));
  }
  async _$EP() {
    this.isUpdatePending = true;
    try {
      await this._$ES;
    } catch (t3) {
      Promise.reject(t3);
    }
    const t2 = this.scheduleUpdate();
    return null != t2 && await t2, !this.isUpdatePending;
  }
  scheduleUpdate() {
    return this.performUpdate();
  }
  performUpdate() {
    var _a2;
    if (!this.isUpdatePending) return;
    if (!this.hasUpdated) {
      if (this.renderRoot ?? (this.renderRoot = this.createRenderRoot()), this._$Ep) {
        for (const [t4, s3] of this._$Ep) this[t4] = s3;
        this._$Ep = void 0;
      }
      const t3 = this.constructor.elementProperties;
      if (t3.size > 0) for (const [s3, i3] of t3) {
        const { wrapped: t4 } = i3, e2 = this[s3];
        true !== t4 || this._$AL.has(s3) || void 0 === e2 || this.C(s3, void 0, i3, e2);
      }
    }
    let t2 = false;
    const s2 = this._$AL;
    try {
      t2 = this.shouldUpdate(s2), t2 ? (this.willUpdate(s2), (_a2 = this._$EO) == null ? void 0 : _a2.forEach((t3) => {
        var _a3;
        return (_a3 = t3.hostUpdate) == null ? void 0 : _a3.call(t3);
      }), this.update(s2)) : this._$EM();
    } catch (s3) {
      throw t2 = false, this._$EM(), s3;
    }
    t2 && this._$AE(s2);
  }
  willUpdate(t2) {
  }
  _$AE(t2) {
    var _a2;
    (_a2 = this._$EO) == null ? void 0 : _a2.forEach((t3) => {
      var _a3;
      return (_a3 = t3.hostUpdated) == null ? void 0 : _a3.call(t3);
    }), this.hasUpdated || (this.hasUpdated = true, this.firstUpdated(t2)), this.updated(t2);
  }
  _$EM() {
    this._$AL = /* @__PURE__ */ new Map(), this.isUpdatePending = false;
  }
  get updateComplete() {
    return this.getUpdateComplete();
  }
  getUpdateComplete() {
    return this._$ES;
  }
  shouldUpdate(t2) {
    return true;
  }
  update(t2) {
    this._$Eq && (this._$Eq = this._$Eq.forEach((t3) => this._$ET(t3, this[t3]))), this._$EM();
  }
  updated(t2) {
  }
  firstUpdated(t2) {
  }
};
y$1.elementStyles = [], y$1.shadowRootOptions = { mode: "open" }, y$1[d$1("elementProperties")] = /* @__PURE__ */ new Map(), y$1[d$1("finalized")] = /* @__PURE__ */ new Map(), p$2 == null ? void 0 : p$2({ ReactiveElement: y$1 }), (a$1.reactiveElementVersions ?? (a$1.reactiveElementVersions = [])).push("2.1.2");
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const t$2 = globalThis, i$2 = (t2) => t2, s$1 = t$2.trustedTypes, e$1 = s$1 ? s$1.createPolicy("lit-html", { createHTML: (t2) => t2 }) : void 0, h = "$lit$", o$2 = `lit$${Math.random().toFixed(9).slice(2)}$`, n$1 = "?" + o$2, r$3 = `<${n$1}>`, l$1 = document, c = () => l$1.createComment(""), a = (t2) => null === t2 || "object" != typeof t2 && "function" != typeof t2, u = Array.isArray, d = (t2) => u(t2) || "function" == typeof (t2 == null ? void 0 : t2[Symbol.iterator]), f = "[ 	\n\f\r]", v = /<(?:(!--|\/[^a-zA-Z])|(\/?[a-zA-Z][^>\s]*)|(\/?$))/g, _ = /-->/g, m$1 = />/g, p$1 = RegExp(`>|${f}(?:([^\\s"'>=/]+)(${f}*=${f}*(?:[^ 	
\f\r"'\`<>=]|("|')|))|$)`, "g"), g = /'/g, $ = /"/g, y2 = /^(?:script|style|textarea|title)$/i, x = (t2) => (i3, ...s2) => ({ _$litType$: t2, strings: i3, values: s2 }), b = x(1), E = Symbol.for("lit-noChange"), A = Symbol.for("lit-nothing"), C = /* @__PURE__ */ new WeakMap(), P = l$1.createTreeWalker(l$1, 129);
function V(t2, i3) {
  if (!u(t2) || !t2.hasOwnProperty("raw")) throw Error("invalid template strings array");
  return void 0 !== e$1 ? e$1.createHTML(i3) : i3;
}
const N = (t2, i3) => {
  const s2 = t2.length - 1, e2 = [];
  let n3, l2 = 2 === i3 ? "<svg>" : 3 === i3 ? "<math>" : "", c2 = v;
  for (let i4 = 0; i4 < s2; i4++) {
    const s3 = t2[i4];
    let a2, u2, d2 = -1, f2 = 0;
    for (; f2 < s3.length && (c2.lastIndex = f2, u2 = c2.exec(s3), null !== u2); ) f2 = c2.lastIndex, c2 === v ? "!--" === u2[1] ? c2 = _ : void 0 !== u2[1] ? c2 = m$1 : void 0 !== u2[2] ? (y2.test(u2[2]) && (n3 = RegExp("</" + u2[2], "g")), c2 = p$1) : void 0 !== u2[3] && (c2 = p$1) : c2 === p$1 ? ">" === u2[0] ? (c2 = n3 ?? v, d2 = -1) : void 0 === u2[1] ? d2 = -2 : (d2 = c2.lastIndex - u2[2].length, a2 = u2[1], c2 = void 0 === u2[3] ? p$1 : '"' === u2[3] ? $ : g) : c2 === $ || c2 === g ? c2 = p$1 : c2 === _ || c2 === m$1 ? c2 = v : (c2 = p$1, n3 = void 0);
    const x2 = c2 === p$1 && t2[i4 + 1].startsWith("/>") ? " " : "";
    l2 += c2 === v ? s3 + r$3 : d2 >= 0 ? (e2.push(a2), s3.slice(0, d2) + h + s3.slice(d2) + o$2 + x2) : s3 + o$2 + (-2 === d2 ? i4 : x2);
  }
  return [V(t2, l2 + (t2[s2] || "<?>") + (2 === i3 ? "</svg>" : 3 === i3 ? "</math>" : "")), e2];
};
class S {
  constructor({ strings: t2, _$litType$: i3 }, e2) {
    let r2;
    this.parts = [];
    let l2 = 0, a2 = 0;
    const u2 = t2.length - 1, d2 = this.parts, [f2, v2] = N(t2, i3);
    if (this.el = S.createElement(f2, e2), P.currentNode = this.el.content, 2 === i3 || 3 === i3) {
      const t3 = this.el.content.firstChild;
      t3.replaceWith(...t3.childNodes);
    }
    for (; null !== (r2 = P.nextNode()) && d2.length < u2; ) {
      if (1 === r2.nodeType) {
        if (r2.hasAttributes()) for (const t3 of r2.getAttributeNames()) if (t3.endsWith(h)) {
          const i4 = v2[a2++], s2 = r2.getAttribute(t3).split(o$2), e3 = /([.?@])?(.*)/.exec(i4);
          d2.push({ type: 1, index: l2, name: e3[2], strings: s2, ctor: "." === e3[1] ? I : "?" === e3[1] ? L : "@" === e3[1] ? z : H }), r2.removeAttribute(t3);
        } else t3.startsWith(o$2) && (d2.push({ type: 6, index: l2 }), r2.removeAttribute(t3));
        if (y2.test(r2.tagName)) {
          const t3 = r2.textContent.split(o$2), i4 = t3.length - 1;
          if (i4 > 0) {
            r2.textContent = s$1 ? s$1.emptyScript : "";
            for (let s2 = 0; s2 < i4; s2++) r2.append(t3[s2], c()), P.nextNode(), d2.push({ type: 2, index: ++l2 });
            r2.append(t3[i4], c());
          }
        }
      } else if (8 === r2.nodeType) if (r2.data === n$1) d2.push({ type: 2, index: l2 });
      else {
        let t3 = -1;
        for (; -1 !== (t3 = r2.data.indexOf(o$2, t3 + 1)); ) d2.push({ type: 7, index: l2 }), t3 += o$2.length - 1;
      }
      l2++;
    }
  }
  static createElement(t2, i3) {
    const s2 = l$1.createElement("template");
    return s2.innerHTML = t2, s2;
  }
}
function M(t2, i3, s2 = t2, e2) {
  var _a2, _b;
  if (i3 === E) return i3;
  let h2 = void 0 !== e2 ? (_a2 = s2._$Co) == null ? void 0 : _a2[e2] : s2._$Cl;
  const o2 = a(i3) ? void 0 : i3._$litDirective$;
  return (h2 == null ? void 0 : h2.constructor) !== o2 && ((_b = h2 == null ? void 0 : h2._$AO) == null ? void 0 : _b.call(h2, false), void 0 === o2 ? h2 = void 0 : (h2 = new o2(t2), h2._$AT(t2, s2, e2)), void 0 !== e2 ? (s2._$Co ?? (s2._$Co = []))[e2] = h2 : s2._$Cl = h2), void 0 !== h2 && (i3 = M(t2, h2._$AS(t2, i3.values), h2, e2)), i3;
}
class R {
  constructor(t2, i3) {
    this._$AV = [], this._$AN = void 0, this._$AD = t2, this._$AM = i3;
  }
  get parentNode() {
    return this._$AM.parentNode;
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  u(t2) {
    const { el: { content: i3 }, parts: s2 } = this._$AD, e2 = ((t2 == null ? void 0 : t2.creationScope) ?? l$1).importNode(i3, true);
    P.currentNode = e2;
    let h2 = P.nextNode(), o2 = 0, n3 = 0, r2 = s2[0];
    for (; void 0 !== r2; ) {
      if (o2 === r2.index) {
        let i4;
        2 === r2.type ? i4 = new k(h2, h2.nextSibling, this, t2) : 1 === r2.type ? i4 = new r2.ctor(h2, r2.name, r2.strings, this, t2) : 6 === r2.type && (i4 = new Z(h2, this, t2)), this._$AV.push(i4), r2 = s2[++n3];
      }
      o2 !== (r2 == null ? void 0 : r2.index) && (h2 = P.nextNode(), o2++);
    }
    return P.currentNode = l$1, e2;
  }
  p(t2) {
    let i3 = 0;
    for (const s2 of this._$AV) void 0 !== s2 && (void 0 !== s2.strings ? (s2._$AI(t2, s2, i3), i3 += s2.strings.length - 2) : s2._$AI(t2[i3])), i3++;
  }
}
class k {
  get _$AU() {
    var _a2;
    return ((_a2 = this._$AM) == null ? void 0 : _a2._$AU) ?? this._$Cv;
  }
  constructor(t2, i3, s2, e2) {
    this.type = 2, this._$AH = A, this._$AN = void 0, this._$AA = t2, this._$AB = i3, this._$AM = s2, this.options = e2, this._$Cv = (e2 == null ? void 0 : e2.isConnected) ?? true;
  }
  get parentNode() {
    let t2 = this._$AA.parentNode;
    const i3 = this._$AM;
    return void 0 !== i3 && 11 === (t2 == null ? void 0 : t2.nodeType) && (t2 = i3.parentNode), t2;
  }
  get startNode() {
    return this._$AA;
  }
  get endNode() {
    return this._$AB;
  }
  _$AI(t2, i3 = this) {
    t2 = M(this, t2, i3), a(t2) ? t2 === A || null == t2 || "" === t2 ? (this._$AH !== A && this._$AR(), this._$AH = A) : t2 !== this._$AH && t2 !== E && this._(t2) : void 0 !== t2._$litType$ ? this.$(t2) : void 0 !== t2.nodeType ? this.T(t2) : d(t2) ? this.k(t2) : this._(t2);
  }
  O(t2) {
    return this._$AA.parentNode.insertBefore(t2, this._$AB);
  }
  T(t2) {
    this._$AH !== t2 && (this._$AR(), this._$AH = this.O(t2));
  }
  _(t2) {
    this._$AH !== A && a(this._$AH) ? this._$AA.nextSibling.data = t2 : this.T(l$1.createTextNode(t2)), this._$AH = t2;
  }
  $(t2) {
    var _a2;
    const { values: i3, _$litType$: s2 } = t2, e2 = "number" == typeof s2 ? this._$AC(t2) : (void 0 === s2.el && (s2.el = S.createElement(V(s2.h, s2.h[0]), this.options)), s2);
    if (((_a2 = this._$AH) == null ? void 0 : _a2._$AD) === e2) this._$AH.p(i3);
    else {
      const t3 = new R(e2, this), s3 = t3.u(this.options);
      t3.p(i3), this.T(s3), this._$AH = t3;
    }
  }
  _$AC(t2) {
    let i3 = C.get(t2.strings);
    return void 0 === i3 && C.set(t2.strings, i3 = new S(t2)), i3;
  }
  k(t2) {
    u(this._$AH) || (this._$AH = [], this._$AR());
    const i3 = this._$AH;
    let s2, e2 = 0;
    for (const h2 of t2) e2 === i3.length ? i3.push(s2 = new k(this.O(c()), this.O(c()), this, this.options)) : s2 = i3[e2], s2._$AI(h2), e2++;
    e2 < i3.length && (this._$AR(s2 && s2._$AB.nextSibling, e2), i3.length = e2);
  }
  _$AR(t2 = this._$AA.nextSibling, s2) {
    var _a2;
    for ((_a2 = this._$AP) == null ? void 0 : _a2.call(this, false, true, s2); t2 !== this._$AB; ) {
      const s3 = i$2(t2).nextSibling;
      i$2(t2).remove(), t2 = s3;
    }
  }
  setConnected(t2) {
    var _a2;
    void 0 === this._$AM && (this._$Cv = t2, (_a2 = this._$AP) == null ? void 0 : _a2.call(this, t2));
  }
}
class H {
  get tagName() {
    return this.element.tagName;
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  constructor(t2, i3, s2, e2, h2) {
    this.type = 1, this._$AH = A, this._$AN = void 0, this.element = t2, this.name = i3, this._$AM = e2, this.options = h2, s2.length > 2 || "" !== s2[0] || "" !== s2[1] ? (this._$AH = Array(s2.length - 1).fill(new String()), this.strings = s2) : this._$AH = A;
  }
  _$AI(t2, i3 = this, s2, e2) {
    const h2 = this.strings;
    let o2 = false;
    if (void 0 === h2) t2 = M(this, t2, i3, 0), o2 = !a(t2) || t2 !== this._$AH && t2 !== E, o2 && (this._$AH = t2);
    else {
      const e3 = t2;
      let n3, r2;
      for (t2 = h2[0], n3 = 0; n3 < h2.length - 1; n3++) r2 = M(this, e3[s2 + n3], i3, n3), r2 === E && (r2 = this._$AH[n3]), o2 || (o2 = !a(r2) || r2 !== this._$AH[n3]), r2 === A ? t2 = A : t2 !== A && (t2 += (r2 ?? "") + h2[n3 + 1]), this._$AH[n3] = r2;
    }
    o2 && !e2 && this.j(t2);
  }
  j(t2) {
    t2 === A ? this.element.removeAttribute(this.name) : this.element.setAttribute(this.name, t2 ?? "");
  }
}
class I extends H {
  constructor() {
    super(...arguments), this.type = 3;
  }
  j(t2) {
    this.element[this.name] = t2 === A ? void 0 : t2;
  }
}
class L extends H {
  constructor() {
    super(...arguments), this.type = 4;
  }
  j(t2) {
    this.element.toggleAttribute(this.name, !!t2 && t2 !== A);
  }
}
class z extends H {
  constructor(t2, i3, s2, e2, h2) {
    super(t2, i3, s2, e2, h2), this.type = 5;
  }
  _$AI(t2, i3 = this) {
    if ((t2 = M(this, t2, i3, 0) ?? A) === E) return;
    const s2 = this._$AH, e2 = t2 === A && s2 !== A || t2.capture !== s2.capture || t2.once !== s2.once || t2.passive !== s2.passive, h2 = t2 !== A && (s2 === A || e2);
    e2 && this.element.removeEventListener(this.name, this, s2), h2 && this.element.addEventListener(this.name, this, t2), this._$AH = t2;
  }
  handleEvent(t2) {
    var _a2;
    "function" == typeof this._$AH ? this._$AH.call(((_a2 = this.options) == null ? void 0 : _a2.host) ?? this.element, t2) : this._$AH.handleEvent(t2);
  }
}
class Z {
  constructor(t2, i3, s2) {
    this.element = t2, this.type = 6, this._$AN = void 0, this._$AM = i3, this.options = s2;
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  _$AI(t2) {
    M(this, t2);
  }
}
const B = t$2.litHtmlPolyfillSupport;
B == null ? void 0 : B(S, k), (t$2.litHtmlVersions ?? (t$2.litHtmlVersions = [])).push("3.3.3");
const D = (t2, i3, s2) => {
  const e2 = (s2 == null ? void 0 : s2.renderBefore) ?? i3;
  let h2 = e2._$litPart$;
  if (void 0 === h2) {
    const t3 = (s2 == null ? void 0 : s2.renderBefore) ?? null;
    e2._$litPart$ = h2 = new k(i3.insertBefore(c(), t3), t3, void 0, s2 ?? {});
  }
  return h2._$AI(t2), h2;
};
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const s = globalThis;
let i$1 = class i extends y$1 {
  constructor() {
    super(...arguments), this.renderOptions = { host: this }, this._$Do = void 0;
  }
  createRenderRoot() {
    var _a2;
    const t2 = super.createRenderRoot();
    return (_a2 = this.renderOptions).renderBefore ?? (_a2.renderBefore = t2.firstChild), t2;
  }
  update(t2) {
    const r2 = this.render();
    this.hasUpdated || (this.renderOptions.isConnected = this.isConnected), super.update(t2), this._$Do = D(r2, this.renderRoot, this.renderOptions);
  }
  connectedCallback() {
    var _a2;
    super.connectedCallback(), (_a2 = this._$Do) == null ? void 0 : _a2.setConnected(true);
  }
  disconnectedCallback() {
    var _a2;
    super.disconnectedCallback(), (_a2 = this._$Do) == null ? void 0 : _a2.setConnected(false);
  }
  render() {
    return E;
  }
};
i$1._$litElement$ = true, i$1["finalized"] = true, (_a = s.litElementHydrateSupport) == null ? void 0 : _a.call(s, { LitElement: i$1 });
const o$1 = s.litElementPolyfillSupport;
o$1 == null ? void 0 : o$1({ LitElement: i$1 });
(s.litElementVersions ?? (s.litElementVersions = [])).push("4.2.2");
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const t$1 = (t2) => (e2, o2) => {
  void 0 !== o2 ? o2.addInitializer(() => {
    customElements.define(t2, e2);
  }) : customElements.define(t2, e2);
};
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const o = { attribute: true, type: String, converter: u$1, reflect: false, hasChanged: f$1 }, r$2 = (t2 = o, e2, r2) => {
  const { kind: n3, metadata: i3 } = r2;
  let s2 = globalThis.litPropertyMetadata.get(i3);
  if (void 0 === s2 && globalThis.litPropertyMetadata.set(i3, s2 = /* @__PURE__ */ new Map()), "setter" === n3 && ((t2 = Object.create(t2)).wrapped = true), s2.set(r2.name, t2), "accessor" === n3) {
    const { name: o2 } = r2;
    return { set(r3) {
      const n4 = e2.get.call(this);
      e2.set.call(this, r3), this.requestUpdate(o2, n4, t2, true, r3);
    }, init(e3) {
      return void 0 !== e3 && this.C(o2, void 0, t2, e3), e3;
    } };
  }
  if ("setter" === n3) {
    const { name: o2 } = r2;
    return function(r3) {
      const n4 = this[o2];
      e2.call(this, r3), this.requestUpdate(o2, n4, t2, true, r3);
    };
  }
  throw Error("Unsupported decorator location: " + n3);
};
function n2(t2) {
  return (e2, o2) => "object" == typeof o2 ? r$2(t2, e2, o2) : ((t3, e3, o3) => {
    const r2 = e3.hasOwnProperty(o3);
    return e3.constructor.createProperty(o3, t3), r2 ? Object.getOwnPropertyDescriptor(e3, o3) : void 0;
  })(t2, e2, o2);
}
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
function r$1(r2) {
  return n2({ ...r2, state: true, attribute: false });
}
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const t = { ATTRIBUTE: 1, PROPERTY: 3, BOOLEAN_ATTRIBUTE: 4 }, e = (t2) => (...e2) => ({ _$litDirective$: t2, values: e2 });
class i2 {
  constructor(t2) {
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  _$AT(t2, e2, i3) {
    this._$Ct = t2, this._$AM = e2, this._$Ci = i3;
  }
  _$AS(t2, e2) {
    return this.update(t2, e2);
  }
  update(t2, e2) {
    return this.render(...e2);
  }
}
/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const r = (o2) => void 0 === o2.strings, m = {}, p = (o2, t2 = m) => o2._$AH = t2;
/**
 * @license
 * Copyright 2020 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const l = e(class extends i2 {
  constructor(r$12) {
    if (super(r$12), r$12.type !== t.PROPERTY && r$12.type !== t.ATTRIBUTE && r$12.type !== t.BOOLEAN_ATTRIBUTE) throw Error("The `live` directive is not allowed on child or event bindings");
    if (!r(r$12)) throw Error("`live` bindings can only contain a single expression");
  }
  render(r2) {
    return r2;
  }
  update(i3, [t$12]) {
    if (t$12 === E || t$12 === A) return t$12;
    const o2 = i3.element, l2 = i3.name;
    if (i3.type === t.PROPERTY) {
      if (t$12 === o2[l2]) return E;
    } else if (i3.type === t.BOOLEAN_ATTRIBUTE) {
      if (!!t$12 === o2.hasAttribute(l2)) return E;
    } else if (i3.type === t.ATTRIBUTE && o2.getAttribute(l2) === t$12 + "") return E;
    return p(i3), t$12;
  }
});
class JsonParseError extends Error {
  constructor(message, offset) {
    super(`${message} at offset ${offset}`);
    this.name = "JsonParseError";
    this.offset = offset;
  }
}
class Parser {
  constructor(text) {
    this.lineStarts = [0];
    this.i = 0;
    this.text = text;
    for (let k2 = 0; k2 < text.length; k2++) {
      if (text[k2] === "\n") this.lineStarts.push(k2 + 1);
    }
  }
  loc(offset) {
    let lo = 0;
    let hi = this.lineStarts.length - 1;
    while (lo < hi) {
      const mid = lo + hi + 1 >> 1;
      if (this.lineStarts[mid] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return { offset, line: lo, column: offset - this.lineStarts[lo] };
  }
  error(message, offset = this.i) {
    throw new JsonParseError(message, offset);
  }
  skipWs() {
    while (this.i < this.text.length) {
      const c2 = this.text[this.i];
      if (c2 === " " || c2 === "	" || c2 === "\n" || c2 === "\r") this.i++;
      else break;
    }
  }
  parse() {
    this.skipWs();
    const node = this.parseValue();
    this.skipWs();
    if (this.i < this.text.length) {
      this.error(`Unexpected token '${this.text[this.i]}'`);
    }
    return node;
  }
  node(type, start, extra) {
    const startLoc = this.loc(start);
    const endLoc = this.loc(this.i);
    return { type, start, end: this.i, line: startLoc.line, endLine: endLoc.line, ...extra };
  }
  parseValue() {
    if (this.i >= this.text.length) this.error("Unexpected end of JSON input");
    const c2 = this.text[this.i];
    if (c2 === "{") return this.parseObject();
    if (c2 === "[") return this.parseArray();
    if (c2 === '"') return this.parseString();
    if (c2 === "-" || c2 >= "0" && c2 <= "9") return this.parseNumber();
    if (this.text.startsWith("true", this.i)) return this.parseLiteral(true);
    if (this.text.startsWith("false", this.i)) return this.parseLiteral(false);
    if (this.text.startsWith("null", this.i)) return this.parseLiteral(null);
    this.error(`Unexpected token '${c2}'`);
    throw new Error("unreachable");
  }
  parseLiteral(value) {
    const start = this.i;
    const word = value === null ? "null" : value ? "true" : "false";
    this.i += word.length;
    return this.node(value === null ? "null" : "boolean", start, { value });
  }
  parseNumber() {
    const start = this.i;
    const re = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/;
    const m2 = re.exec(this.text.slice(start));
    if (!m2) this.error("Invalid number", start);
    this.i = start + m2[0].length;
    return this.node("number", start, { value: Number(m2[0]) });
  }
  parseString() {
    const start = this.i;
    this.i++;
    let out = "";
    while (true) {
      if (this.i >= this.text.length) this.error("Unterminated string", start);
      const c2 = this.text[this.i];
      if (c2 === '"') {
        this.i++;
        break;
      }
      if (c2 === "\\") {
        this.i++;
        if (this.i >= this.text.length) this.error("Unterminated escape", start);
        const esc = this.text[this.i];
        switch (esc) {
          case '"':
            out += '"';
            break;
          case "\\":
            out += "\\";
            break;
          case "/":
            out += "/";
            break;
          case "b":
            out += "\b";
            break;
          case "f":
            out += "\f";
            break;
          case "n":
            out += "\n";
            break;
          case "r":
            out += "\r";
            break;
          case "t":
            out += "	";
            break;
          case "u": {
            const hex = this.text.slice(this.i + 1, this.i + 5);
            if (!/^[0-9a-fA-F]{4}$/.test(hex)) this.error("Invalid unicode escape", this.i);
            out += String.fromCharCode(parseInt(hex, 16));
            this.i += 4;
            break;
          }
          default:
            this.error(`Invalid escape '\\${esc}'`, this.i);
        }
        this.i++;
        continue;
      }
      if (c2 === "\n" || c2 === "\r") this.error("Unterminated string", start);
      out += c2;
      this.i++;
    }
    return this.node("string", start, { value: out });
  }
  parseObject() {
    const start = this.i;
    this.i++;
    const members = [];
    this.skipWs();
    if (this.text[this.i] === "}") {
      this.i++;
      return this.node("object", start, { value: {}, members });
    }
    while (true) {
      this.skipWs();
      if (this.text[this.i] !== '"') this.error("Expected object key", this.i);
      const keyNode = this.parseString();
      this.skipWs();
      if (this.text[this.i] !== ":") this.error("Expected ':' after key", this.i);
      this.i++;
      this.skipWs();
      const value = this.parseValue();
      members.push({
        key: String(keyNode.value),
        keyStart: keyNode.start,
        keyEnd: keyNode.end,
        keyLine: keyNode.line,
        value
      });
      this.skipWs();
      const c2 = this.text[this.i];
      if (c2 === ",") {
        this.i++;
        this.skipWs();
        if (this.text[this.i] === "}") this.error("Trailing comma", this.i);
        continue;
      }
      if (c2 === "}") {
        this.i++;
        break;
      }
      if (c2 === "") this.error("Unexpected end of JSON input");
      this.error(`Expected ',' or '}', got '${c2}'`, this.i);
    }
    const obj = {};
    for (const m2 of members) obj[m2.key] = m2.value.value;
    return this.node("object", start, { value: obj, members });
  }
  parseArray() {
    const start = this.i;
    this.i++;
    const elements = [];
    this.skipWs();
    if (this.text[this.i] === "]") {
      this.i++;
      return this.node("array", start, { value: [], elements });
    }
    while (true) {
      this.skipWs();
      const value = this.parseValue();
      elements.push(value);
      this.skipWs();
      const c2 = this.text[this.i];
      if (c2 === ",") {
        this.i++;
        this.skipWs();
        if (this.text[this.i] === "]") this.error("Trailing comma", this.i);
        continue;
      }
      if (c2 === "]") {
        this.i++;
        break;
      }
      if (c2 === "") this.error("Unexpected end of JSON input");
      this.error(`Expected ',' or ']', got '${c2}'`, this.i);
    }
    return this.node("array", start, {
      value: elements.map((e2) => e2.value),
      elements
    });
  }
}
function parseJson(text) {
  try {
    const p2 = new Parser(text);
    const root = p2.parse();
    return { ok: true, value: root.value, root };
  } catch (err) {
    if (err instanceof JsonParseError) {
      const loc = new Parser(text).loc(err.offset);
      return { ok: false, error: { ...loc, message: err.message } };
    }
    throw err;
  }
}
function pathForLine(node, line, path = []) {
  if (node.type === "object" && node.members) {
    for (const m2 of node.members) {
      if (m2.keyLine === line) return [...path, m2.key];
      const r2 = pathForLine(m2.value, line, [...path, m2.key]);
      if (r2) return r2;
    }
  } else if (node.type === "array" && node.elements) {
    for (let i3 = 0; i3 < node.elements.length; i3++) {
      const el = node.elements[i3];
      if (el.line === line) return [...path, i3];
      const r2 = pathForLine(el, line, [...path, i3]);
      if (r2) return r2;
    }
  }
  return null;
}
function schemaAtPath(schema, path) {
  let s2 = schema;
  for (const seg of path) {
    if (s2 === null || typeof s2 !== "object") return null;
    const obj = s2;
    if (typeof seg === "number") {
      const items = obj.items;
      if (Array.isArray(items)) s2 = items[seg];
      else s2 = items;
    } else {
      const props = obj.properties;
      s2 = props ? props[seg] : void 0;
      if (s2 === void 0) {
        const ap = obj.additionalProperties;
        if (ap && typeof ap === "object") s2 = ap;
        else if (ap === true) s2 = { type: void 0, description: void 0 };
        else s2 = void 0;
      }
    }
    if (!s2) return null;
  }
  return s2;
}
function schemaDescription(schema) {
  if (schema === null || typeof schema !== "object") return null;
  const d2 = schema.description;
  return typeof d2 === "string" && d2.trim() ? d2 : null;
}
function schemaDescriptionForPath(schema, path) {
  for (let i3 = path.length; i3 >= 0; i3--) {
    const d2 = schemaDescription(schemaAtPath(schema, path.slice(0, i3)));
    if (d2) return d2;
  }
  return null;
}
function asObj(schema) {
  return schema !== null && typeof schema === "object" ? schema : null;
}
function schemaTypeLabel(schema) {
  const s2 = asObj(schema);
  if (!s2) return "any";
  const t2 = s2.type;
  if (Array.isArray(t2)) {
    const ts = t2.filter((x2) => x2 !== "null");
    return ts.length ? ts.map((x2) => String(x2)).join("|") : "any";
  }
  if (typeof t2 === "string") {
    if (t2 === "array") {
      const item = asObj(s2.items);
      return item && item.type === "string" ? "string[]" : "array";
    }
    return t2;
  }
  return "any";
}
function schemaItemHint(schema) {
  const s2 = asObj(schema);
  if (!s2 || s2.type !== "array") return null;
  const items = asObj(s2.items);
  const props = items && items.properties;
  if (!props || typeof props !== "object" || Object.keys(props).length === 0) return null;
  const parts = Object.entries(props).map(([k2, v2]) => `${k2}: ${schemaTypeLabel(v2)}`);
  return `Each item: { ${parts.join(", ")} }`;
}
function pathKey(path) {
  let out = "";
  for (const seg of path) {
    if (typeof seg === "number") {
      out += `[${seg}]`;
    } else {
      out += (out === "" ? "" : ".") + seg;
    }
  }
  return out;
}
function cloneDeep(value) {
  if (value === void 0) return value;
  return JSON.parse(JSON.stringify(value));
}
function jsonEqual(a2, b2) {
  return JSON.stringify(a2) === JSON.stringify(b2);
}
function stripDefaults(value, defaults, explicitPaths, path = "") {
  if (Array.isArray(value)) {
    if (path !== "" && (explicitPaths == null ? void 0 : explicitPaths.has(path))) return value;
    return jsonEqual(value, defaults) ? void 0 : value;
  }
  if (value !== null && typeof value === "object") {
    if (path !== "" && (explicitPaths == null ? void 0 : explicitPaths.has(path))) return value;
    const src = value;
    const def = defaults && typeof defaults === "object" && !Array.isArray(defaults) ? defaults : {};
    const out = {};
    for (const key of Object.keys(src)) {
      const dv = src[key];
      if (dv === void 0) continue;
      const cur = path ? `${path}.${key}` : key;
      if (Array.isArray(dv)) {
        if (path !== "" && (explicitPaths == null ? void 0 : explicitPaths.has(cur))) out[key] = dv;
        else if (!jsonEqual(dv, def[key])) out[key] = dv;
      } else if (dv !== null && typeof dv === "object") {
        const pruned = stripDefaults(dv, def[key], explicitPaths, cur);
        if (pruned !== void 0 && Object.keys(pruned).length > 0) out[key] = pruned;
      } else if (!jsonEqual(dv, def[key]) || ((explicitPaths == null ? void 0 : explicitPaths.has(cur)) ?? false)) {
        out[key] = dv;
      }
    }
    return out;
  }
  return jsonEqual(value, defaults) ? void 0 : value;
}
function mergeDefaults(value, defaults) {
  const out = cloneDeep(defaults);
  applyOverrides(out, value);
  return out;
}
function applyOverrides(target, overrides) {
  if (!overrides || typeof overrides !== "object" || Array.isArray(overrides)) return;
  for (const [key, v2] of Object.entries(overrides)) {
    if (v2 === void 0) continue;
    const t2 = target[key];
    if (v2 !== null && typeof v2 === "object" && !Array.isArray(v2) && t2 && typeof t2 === "object" && !Array.isArray(t2)) {
      applyOverrides(t2, v2);
    } else {
      target[key] = v2;
    }
  }
}
function getAt(value, path) {
  let cur = value;
  for (const seg of path) {
    if (cur == null) return void 0;
    if (Array.isArray(cur)) {
      cur = cur[seg];
    } else if (typeof cur === "object") {
      cur = cur[seg];
    } else {
      return void 0;
    }
  }
  return cur;
}
function summarize(value) {
  const entries = Array.isArray(value) ? value : Object.values(value);
  const counts = { string: 0, number: 0, boolean: 0, object: 0, array: 0, null: 0 };
  for (const v2 of entries) {
    if (v2 === null) counts.null++;
    else if (Array.isArray(v2)) counts.array++;
    else if (typeof v2 === "object") counts.object++;
    else if (typeof v2 === "string") counts.string++;
    else if (typeof v2 === "number") counts.number++;
    else if (typeof v2 === "boolean") counts.boolean++;
  }
  const parts = [];
  if (Array.isArray(value)) {
    parts.push(`${entries.length} item${entries.length === 1 ? "" : "s"}`);
  } else {
    parts.push(`${entries.length} propert${entries.length === 1 ? "y" : "ies"}`);
  }
  if (counts.string) parts.push(`${counts.string} string${counts.string === 1 ? "" : "s"}`);
  if (counts.number) parts.push(`${counts.number} number${counts.number === 1 ? "" : "s"}`);
  if (counts.boolean) parts.push(`${counts.boolean} boolean${counts.boolean === 1 ? "" : "s"}`);
  if (counts.object) parts.push(`${counts.object} object${counts.object === 1 ? "" : "s"}`);
  if (counts.array) parts.push(`${counts.array} arra${counts.array === 1 ? "y" : "ys"}`);
  if (counts.null) parts.push(`${counts.null} null${counts.null === 1 ? "" : "s"}`);
  return parts.join(" · ");
}
function stringAt(text, pos) {
  if (pos < 0) return null;
  let open = -1;
  let esc = false;
  let inStr = false;
  for (let i3 = 0; i3 < text.length; i3++) {
    const c2 = text[i3];
    if (inStr) {
      if (esc) {
        esc = false;
        continue;
      }
      if (c2 === "\\") {
        esc = true;
        continue;
      }
      if (c2 === '"') {
        if (pos > open && pos <= i3) return { open, close: i3 };
        inStr = false;
        open = -1;
      }
      continue;
    }
    if (c2 === '"') {
      inStr = true;
      open = i3;
    }
  }
  return null;
}
function ownerPathAt(text, lineStart) {
  const stack = [];
  let pendingKey = null;
  let i3 = 0;
  while (i3 < lineStart) {
    const c2 = text[i3];
    if (c2 === '"') {
      let j = i3 + 1;
      let s2 = "";
      while (j < lineStart) {
        const cc = text[j];
        if (cc === "\\") {
          s2 += text[j + 1] ?? "";
          j += 2;
          continue;
        }
        if (cc === '"') break;
        s2 += cc;
        j++;
      }
      let k2 = j + 1;
      while (k2 < lineStart && (text[k2] === " " || text[k2] === "	" || text[k2] === "\n" || text[k2] === "\r")) {
        k2++;
      }
      const isKey = text[k2] === ":";
      const topNow2 = stack[stack.length - 1];
      if (topNow2 && topNow2.kind === "arr") topNow2.elems++;
      pendingKey = isKey ? s2 : null;
      i3 = j + 1;
      continue;
    }
    if (c2 === "{" || c2 === "[") {
      const topNow2 = stack[stack.length - 1];
      const elemIndex = topNow2 && topNow2.kind === "arr" ? topNow2.elems++ : null;
      stack.push({ kind: c2 === "{" ? "obj" : "arr", key: pendingKey, elemIndex, elems: 0 });
      pendingKey = null;
      i3++;
      continue;
    }
    if (c2 === "}") {
      if (stack.length) stack.pop();
      i3++;
      continue;
    }
    if (c2 === "]") {
      if (stack.length) stack.pop();
      i3++;
      continue;
    }
    if (c2 === ",") {
      pendingKey = null;
      i3++;
      continue;
    }
    const topNow = stack[stack.length - 1];
    if (topNow && topNow.kind === "arr" && (c2 >= "0" && c2 <= "9" || c2 === "-" || c2 === "t" || c2 === "f" || c2 === "n")) {
      topNow.elems++;
      let j = i3 + 1;
      while (j < lineStart && text[j] !== "," && text[j] !== "]" && !/\s/.test(text[j])) j++;
      i3 = j;
      continue;
    }
    i3++;
  }
  const top = stack[stack.length - 1];
  if (!top || top.kind !== "obj") return null;
  const path = [];
  for (let n3 = 1; n3 < stack.length; n3++) {
    const f2 = stack[n3];
    if (f2.elemIndex !== null) {
      path.push(f2.elemIndex);
    } else if (f2.key !== null) {
      path.push(f2.key);
    } else {
      return null;
    }
  }
  return path;
}
function suggestContextAt(text, pos) {
  if (pos < 0) return null;
  const s2 = stringAt(text, pos);
  if (!s2) return null;
  const lineStart = text.lastIndexOf("\n", s2.open - 1) + 1;
  const before = text.slice(lineStart, s2.open);
  if (!/^[\t ]*$/.test(before)) return null;
  let k2 = s2.close + 1;
  while (k2 < text.length && (text[k2] === " " || text[k2] === "	")) k2++;
  if (text[k2] === ":") return null;
  const ownerPath = ownerPathAt(text, lineStart);
  if (!ownerPath) return null;
  const prefix2 = text.slice(s2.open + 1, pos);
  return { ownerPath, prefix: prefix2 };
}
function collectKeySuggestions(schema, ownerPath, parsedValue, prefix2) {
  const objSchema = schemaAtPath(schema, ownerPath);
  const props = objSchema && typeof objSchema === "object" ? objSchema.properties : void 0;
  if (!props || typeof props !== "object") {
    const obj = objSchema && typeof objSchema === "object" ? objSchema : null;
    if (!obj || obj.type !== "object") return [];
    const ap = obj.additionalProperties;
    const apObj = ap && typeof ap === "object" ? ap : null;
    if (prefix2 !== "") return [];
    return [
      {
        key: "",
        label: "new key",
        description: "Add a new key (any name).",
        type: apObj ? normalizeType(apObj.type) : void 0
      }
    ];
  }
  const cur = parsedValue == null ? void 0 : getAt(parsedValue, ownerPath);
  const existing = cur && typeof cur === "object" && !Array.isArray(cur) ? new Set(Object.keys(cur)) : /* @__PURE__ */ new Set();
  const p2 = prefix2.toLowerCase();
  const entries = Object.entries(props);
  const out = [];
  for (const [k2, v2] of entries) {
    if (existing.has(k2)) continue;
    if (p2 !== "" && !k2.toLowerCase().startsWith(p2)) continue;
    const prop = v2;
    out.push({
      key: k2,
      description: schemaDescription(v2),
      type: normalizeType(prop == null ? void 0 : prop.type)
    });
  }
  return out;
}
function normalizeType(type) {
  if (typeof type === "string") return type;
  if (Array.isArray(type)) {
    const t2 = type.find((x2) => typeof x2 === "string" && x2 !== "null");
    return typeof t2 === "string" ? t2 : void 0;
  }
  return void 0;
}
function defaultLiteralForType(type) {
  switch (type) {
    case "number":
    case "integer":
      return { value: "0", inside: false };
    case "boolean":
      return { value: "false", inside: false };
    case "object":
      return { value: "{}", inside: true };
    case "array":
      return { value: "[]", inside: true };
    case "null":
      return { value: "null", inside: false };
    case "string":
    default:
      return { value: '""', inside: true };
  }
}
function memberValueKey(text, stringOpen) {
  let i3 = stringOpen - 1;
  while (i3 >= 0 && (text[i3] === " " || text[i3] === "	")) i3--;
  if (i3 < 0 || text[i3] !== ":") return null;
  let j = i3 - 1;
  while (j >= 0 && (text[j] === " " || text[j] === "	")) j--;
  if (j < 0 || text[j] !== '"') return null;
  let k2 = j - 1;
  let esc = false;
  while (k2 >= 0) {
    const c2 = text[k2];
    if (esc) {
      esc = false;
      k2--;
      continue;
    }
    if (c2 === "\\") {
      esc = true;
      k2--;
      continue;
    }
    if (c2 === '"') break;
    k2--;
  }
  if (k2 < 0) return null;
  return text.slice(k2 + 1, j).replace(/\\(["\\/bfnrt])/g, "$1");
}
function valueSuggestContextAt(schema, text, pos, selected) {
  if (pos < 0) return null;
  const s2 = stringAt(text, pos);
  if (!s2) return null;
  const key = memberValueKey(text, s2.open);
  if (key === null) return null;
  const lineStart = text.lastIndexOf("\n", s2.open - 1) + 1;
  const ownerPath = ownerPathAt(text, lineStart);
  if (!ownerPath) return null;
  const path = [...ownerPath, key];
  const prop = schemaAtPath(schema, path);
  if (!prop || typeof prop !== "object") return null;
  const p2 = prop;
  const values = Array.isArray(p2.enum) ? p2.enum.filter((v2) => typeof v2 === "string") : [];
  if (values.length === 0) return null;
  if (selected) {
    return {
      path,
      open: s2.open,
      close: s2.close,
      content: text.slice(s2.open + 1, s2.close),
      values,
      description: typeof p2.description === "string" ? p2.description : null
    };
  }
  const prefix2 = text.slice(s2.open + 1, pos).toLowerCase();
  const filtered = values.filter((v2) => prefix2 === "" || v2.toLowerCase().startsWith(prefix2));
  if (filtered.length === 0) return null;
  return {
    path,
    open: s2.open,
    close: s2.close,
    content: text.slice(s2.open + 1, s2.close),
    values: filtered,
    description: typeof p2.description === "string" ? p2.description : null
  };
}
function computeFoldRanges(text) {
  const lines = text.split("\n");
  const stack = [];
  const out = [];
  let inStr = false;
  let esc = false;
  for (let line = 0; line < lines.length; line++) {
    const s2 = lines[line];
    for (let c2 = 0; c2 < s2.length; c2++) {
      const ch = s2[c2];
      if (inStr) {
        if (esc) esc = false;
        else if (ch === "\\") esc = true;
        else if (ch === '"') inStr = false;
        continue;
      }
      if (ch === '"') inStr = true;
      else if (ch === "{" || ch === "[") stack.push({ ch, line });
      else if (ch === "}" || ch === "]") {
        const top = stack.pop();
        if (top && (top.ch === "{" && ch === "}" || top.ch === "[" && ch === "]")) {
          if (line > top.line) {
            out.push({
              openLine: top.line,
              closeLine: line,
              kind: top.ch === "{" ? "object" : "array"
            });
          }
        }
      }
    }
  }
  return out.sort((a2, b2) => a2.openLine - b2.openLine || a2.closeLine - b2.closeLine);
}
function findEntryAtLine(root, line) {
  if (root.type === "object" && root.members) {
    for (let i3 = 0; i3 < root.members.length; i3++) {
      const m2 = root.members[i3];
      if (m2.keyLine === line || m2.value.line === line) {
        return { parent: root, member: { key: m2.key, index: i3 }, node: m2.value, line: m2.keyLine };
      }
    }
    for (const m2 of root.members) {
      const r2 = findEntryAtLine(m2.value, line);
      if (r2) return r2;
    }
  } else if (root.type === "array" && root.elements) {
    for (let i3 = 0; i3 < root.elements.length; i3++) {
      const el = root.elements[i3];
      if (el.line === line) {
        return { parent: root, index: i3, node: el, line };
      }
    }
    for (const el of root.elements) {
      const r2 = findEntryAtLine(el, line);
      if (r2) return r2;
    }
  }
  return null;
}
function tokenizeJsonFull(text) {
  const tokens = [];
  const n3 = text.length;
  let i3 = 0;
  while (i3 < n3) {
    const c2 = text[i3];
    if (c2 === " " || c2 === "	" || c2 === "\n" || c2 === "\r") {
      let j = i3 + 1;
      while (j < n3 && (text[j] === " " || text[j] === "	" || text[j] === "\n" || text[j] === "\r"))
        j++;
      tokens.push({ kind: "ws", start: i3, end: j, value: text.slice(i3, j) });
      i3 = j;
      continue;
    }
    if (c2 === '"') {
      let j = i3 + 1;
      while (j < n3) {
        const cc = text[j];
        if (cc === "\\") {
          j += 2;
          continue;
        }
        if (cc === '"') {
          j++;
          break;
        }
        j++;
      }
      tokens.push({ kind: "string", start: i3, end: j, value: text.slice(i3, j) });
      i3 = j;
      continue;
    }
    if (c2 === "-" || c2 >= "0" && c2 <= "9") {
      let j = i3 + 1;
      while (j < n3 && /[0-9eE+\-.]/.test(text[j])) j++;
      tokens.push({ kind: "number", start: i3, end: j, value: text.slice(i3, j) });
      i3 = j;
      continue;
    }
    if ("{}[]:,".includes(c2)) {
      tokens.push({ kind: "punct", start: i3, end: i3 + 1, value: c2 });
      i3++;
      continue;
    }
    if (text.startsWith("true", i3) || text.startsWith("false", i3) || text.startsWith("null", i3)) {
      const word = text.startsWith("true", i3) ? "true" : text.startsWith("false", i3) ? "false" : "null";
      tokens.push({ kind: "keyword", start: i3, end: i3 + word.length, value: word });
      i3 += word.length;
      continue;
    }
    tokens.push({ kind: "punct", start: i3, end: i3 + 1, value: c2 });
    i3++;
  }
  return tokens;
}
function selectableRanges(tokens) {
  const res = [];
  const nonWs = tokens.filter((t2) => t2.kind !== "ws");
  for (let idx = 0; idx < nonWs.length; idx++) {
    const t2 = nonWs[idx];
    if (t2.kind === "string") {
      const next = nonWs[idx + 1];
      const isKey = next && next.kind === "punct" && next.value === ":";
      res.push({
        kind: isKey ? "key" : "value",
        start: t2.start + 1,
        end: Math.max(t2.start + 1, t2.end - 1)
      });
    } else if (t2.kind === "number" || t2.kind === "keyword") {
      res.push({ kind: "value", start: t2.start, end: t2.end });
    }
  }
  return res;
}
const NUMBER_RE = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/;
const JSON_SCOPE_CLASS = {
  key: "s-var",
  string: "s-str",
  number: "s-num",
  literal: "s-kw",
  punct: "s-pun",
  plain: ""
};
function tokenizeJsonText(text) {
  const tokens = [];
  let i3 = 0;
  const n3 = text.length;
  while (i3 < n3) {
    const ch = text[i3];
    if (ch === " " || ch === "	" || ch === "\n" || ch === "\r") {
      let j = i3 + 1;
      while (j < n3 && /[ \t\n\r]/.test(text[j])) j++;
      tokens.push({ text: text.slice(i3, j), scope: "plain" });
      i3 = j;
      continue;
    }
    if (ch === "{" || ch === "}" || ch === "[" || ch === "]" || ch === ":" || ch === ",") {
      tokens.push({ text: ch, scope: "punct" });
      i3++;
      continue;
    }
    if (ch === '"') {
      let j = i3 + 1;
      let escaped = false;
      while (j < n3) {
        const c2 = text[j];
        if (escaped) {
          escaped = false;
        } else if (c2 === "\\") {
          escaped = true;
        } else if (c2 === '"') {
          j++;
          break;
        }
        j++;
      }
      const str = text.slice(i3, j);
      const k2 = skipWhitespace(text, j);
      tokens.push({ text: str, scope: text[k2] === ":" ? "key" : "string" });
      i3 = j;
      continue;
    }
    if (ch === "-" || ch >= "0" && ch <= "9") {
      const match = NUMBER_RE.exec(text.slice(i3));
      if (match) {
        tokens.push({ text: match[0], scope: "number" });
        i3 += match[0].length;
        continue;
      }
    }
    if (text.startsWith("true", i3)) {
      tokens.push({ text: "true", scope: "literal" });
      i3 += 4;
      continue;
    }
    if (text.startsWith("false", i3)) {
      tokens.push({ text: "false", scope: "literal" });
      i3 += 5;
      continue;
    }
    if (text.startsWith("null", i3)) {
      tokens.push({ text: "null", scope: "literal" });
      i3 += 4;
      continue;
    }
    tokens.push({ text: ch, scope: "plain" });
    i3++;
  }
  return tokens;
}
function skipWhitespace(text, i3) {
  while (i3 < text.length && /[ \t\n\r]/.test(text[i3])) i3++;
  return i3;
}
function highlightJsonToHtml(text) {
  let out = "";
  for (const tok of tokenizeJsonText(text)) {
    const cls = JSON_SCOPE_CLASS[tok.scope];
    const escaped = tok.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    out += cls ? `<span class="${cls}">${escaped}</span>` : escaped;
  }
  return out;
}
function escapeHtml(s2) {
  return s2.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function inline(s2) {
  return s2.replace(/`([^`]+)`/g, (_m, code) => `<code>${code}</code>`).replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>").replace(/(^|[^*])\*([^*]+)\*/g, "$1<em>$2</em>").replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
}
function highlightCodeBlock(code, lang) {
  switch (lang.trim().toLowerCase()) {
    case "json":
      return highlightJsonToHtml(code);
    default:
      return escapeHtml(code);
  }
}
function isMarkdownFileRef(text) {
  const t2 = text.trim();
  if (!t2 || /\s/.test(t2)) return false;
  return /^(?!\/)(?:(?:\.{1,2})\/)?[\w\-]+(?:\/[\w\-]+)*\.md$/i.test(t2);
}
function renderMarkdown(md) {
  const lines = md.split(/\r?\n/);
  const out = [];
  let listType = null;
  let para = [];
  let inFence = false;
  let fenceLang = "";
  let fenceBody = [];
  const closeList = () => {
    if (listType) {
      out.push(`</${listType}>`);
      listType = null;
    }
  };
  const flushPara = () => {
    if (para.length) {
      out.push(`<p>${inline(escapeHtml(para.join(" ")))}</p>`);
      para = [];
    }
  };
  const flushFence = () => {
    if (fenceBody.length) {
      const body = fenceBody.join("\n");
      const lang = fenceLang;
      out.push(
        `<pre class="je-md-code" data-lang="${escapeHtml(lang)}"><code>${highlightCodeBlock(body, lang)}</code></pre>`
      );
    }
    fenceBody = [];
  };
  for (let i3 = 0; i3 < lines.length; i3++) {
    const line = lines[i3];
    const trimmed = line.trim();
    const fenceOpen = trimmed.match(/^```(\S*)\s*$/);
    if (fenceOpen) {
      if (!inFence) {
        closeList();
        flushPara();
        inFence = true;
        fenceLang = fenceOpen[1];
        fenceBody = [];
      } else {
        flushFence();
        inFence = false;
        fenceLang = "";
      }
      continue;
    }
    if (inFence) {
      fenceBody.push(line);
      continue;
    }
    if (!trimmed) {
      closeList();
      flushPara();
      continue;
    }
    const heading = line.match(/^(#{1,4})\s+(.*)$/);
    if (heading) {
      closeList();
      flushPara();
      const level = Math.min(heading[1].length, 4);
      out.push(`<h${level}>${inline(escapeHtml(heading[2]))}</h${level}>`);
      continue;
    }
    if (/^\s*([-*_])\s*(?:\1\s*){2,}$/.test(line)) {
      closeList();
      flushPara();
      out.push(`<hr>`);
      continue;
    }
    if (trimmed.startsWith(">")) {
      closeList();
      flushPara();
      const quote = [];
      while (i3 < lines.length && lines[i3].trim().startsWith(">")) {
        quote.push(lines[i3].trim().replace(/^>\s?/, ""));
        i3++;
      }
      i3--;
      out.push(`<blockquote>${inline(escapeHtml(quote.join(" ")))}</blockquote>`);
      continue;
    }
    const list = line.match(/^(?:(\d+)\.\s+|[-*]\s+)(.*)$/);
    if (list) {
      flushPara();
      const type = list[1] ? "ol" : "ul";
      if (listType !== type) {
        closeList();
        out.push(`<${type}>`);
        listType = type;
      }
      out.push(`<li>${inline(escapeHtml(list[2]))}</li>`);
      continue;
    }
    para.push(trimmed);
  }
  if (inFence) flushFence();
  flushPara();
  closeList();
  return out.join("");
}
const DRAG_THRESHOLD_PX = 3;
class Gutter {
  constructor(opts = {}) {
    this._columns = [];
    this._rows = [];
    this._hoverKey = null;
    this._activeKey = null;
    this._disposeDoc = null;
    this._hoverBoxState = null;
    this._anchor = null;
    this._dragging = false;
    this._dragMoved = false;
    this._dragStartX = 0;
    this._dragStartY = 0;
    this._onMouseOver = (event) => {
      var _a2, _b, _c, _d;
      const target = event.target;
      const chevron = target && ((_a2 = target.closest) == null ? void 0 : _a2.call(target, ".eg-fold-chevron"));
      if (chevron) {
        if (this._hoverKey !== null) this._applyHover(null);
        return;
      }
      const cell = target && ((_b = target.closest) == null ? void 0 : _b.call(target, ".eg-cell"));
      if (!cell || !cell.dataset.key) return;
      const key = Number(cell.dataset.key);
      const state = this._columns.find((c2) => c2.root.contains(cell));
      const row = this._rows.find((r2) => r2.key === key);
      if (!state || !row) return;
      if (!this._columnHighlightable(state, row)) {
        if (this._hoverKey !== null) this._applyHover(null);
        return;
      }
      if (key !== this._hoverKey) {
        this._applyHover(key);
        (_d = (_c = this._events).onHoverChange) == null ? void 0 : _d.call(_c, key);
      }
    };
    this._onMouseOut = (event) => {
      var _a2, _b;
      const related = event.relatedTarget;
      if (related && this.root.contains(related)) return;
      if (this._hoverKey !== null) {
        this._applyHover(null);
        (_b = (_a2 = this._events).onHoverChange) == null ? void 0 : _b.call(_a2, null);
      }
    };
    this._hoverBoxRaf = 0;
    this._background = opts.background;
    this._events = opts.events ?? {};
    this._hoverBox = opts.hoverBox ?? true;
    this.root = document.createElement("div");
    this.root.className = "eg-gutter";
    this.root.style.display = "flex";
    this.root.style.flexDirection = "row";
    this.root.addEventListener("mouseover", this._onMouseOver);
    this.root.addEventListener("mouseout", this._onMouseOut);
  }
  // ── Columns ──────────────────────────────────────────────────────────────
  setColumns(columns) {
    var _a2, _b;
    for (const state of this._columns) {
      state.root.remove();
    }
    this._columns = [];
    for (const column of columns) {
      const root = document.createElement("div");
      root.className = "eg-col" + (column.className ? " " + column.className() : "") + " eg-col--" + column.id;
      const bg = ((_a2 = column.background) == null ? void 0 : _a2.call(column)) ?? this._background;
      root.style.width = column.width() + "px";
      root.style.background = bg ?? "";
      root.style.display = ((_b = column.visible) == null ? void 0 : _b.call(column)) === false ? "none" : "";
      root.style.position = "relative";
      root.style.flexShrink = "0";
      this._columns.push({ column, root, cells: /* @__PURE__ */ new Map() });
      this.root.appendChild(root);
    }
    this._syncHoverBox(false);
  }
  /** Update the width/background/visibility of every column (call when they change). */
  reflow() {
    var _a2, _b, _c, _d;
    for (const state of this._columns) {
      state.root.style.width = state.column.width() + "px";
      const bg = ((_b = (_a2 = state.column).background) == null ? void 0 : _b.call(_a2)) ?? this._background;
      state.root.style.background = bg ?? "";
      state.root.style.display = ((_d = (_c = state.column).visible) == null ? void 0 : _d.call(_c)) === false ? "none" : "";
      state.root.style.position = "relative";
      state.root.style.flexShrink = "0";
    }
    this._syncHoverBox(false);
  }
  // ── Rows ─────────────────────────────────────────────────────────────────
  /** Replace the row set. Cells are created/updated for visible rows and
   * pruned for rows that no longer exist. Columns diff cheaply via `update`. */
  setRows(rows, dataFor) {
    this._rows = rows;
    this._dataFor = dataFor;
    const seen = /* @__PURE__ */ new Set();
    for (const state of this._columns) {
      const cells = state.cells;
      for (const row of rows) {
        seen.add(row.key);
        let cell = cells.get(row.key);
        const data = dataFor == null ? void 0 : dataFor(row.key);
        if (!cell) {
          cell = state.column.create();
          cell.className = "eg-cell" + (cell.className ? " " + cell.className : "");
          cell.style.position = "absolute";
          cell.style.left = "0";
          cell.style.right = "0";
          cell.style.top = row.top + "px";
          cell.style.height = row.height + "px";
          cell.addEventListener("mousedown", (e2) => this._onCellMousedown(state, row, e2));
          cell.dataset.key = String(row.key);
          cells.set(row.key, cell);
          state.root.appendChild(cell);
        }
        if (cell.__top !== row.top) {
          cell.style.top = row.top + "px";
          cell.__top = row.top;
        }
        if (cell.__height !== row.height) {
          cell.style.height = row.height + "px";
          cell.__height = row.height;
        }
        state.column.update(cell, row, this._ctxFor(row, data));
      }
      for (const key of Array.from(cells.keys())) {
        if (!seen.has(key)) {
          const cell = cells.get(key);
          cell.remove();
          cells.delete(key);
        }
      }
    }
    this._syncHoverBox(false);
  }
  // ── Hover / active ───────────────────────────────────────────────────────
  /** Set the hovered row (null to clear). Broadcast to all cells and paints
   * the unified highlight box. Editor-driven; does not emit `onHoverChange`. */
  setHoverRow(key) {
    this._applyHover(key);
  }
  setActiveRow(key) {
    if (key === this._activeKey) return;
    this._activeKey = key;
    this._applyHoverToCells();
  }
  /**
   * Force a full repaint of every cell with fresh `data`. Call when row data
   * that is not reflected in `setRows`/`setActiveRow`/`setHoverRow` changed
   * (e.g. relative line-number mode, where every label depends on the cursor).
   */
  refresh() {
    this._applyHoverToCells();
  }
  // ── Geometry helpers ─────────────────────────────────────────────────────
  /** The row whose [top, top+height) contains the given client-space Y
   * coordinate, or null. Used to track drags. */
  rowAtClientY(clientY) {
    const rect = this.root.getBoundingClientRect();
    const offset = clientY - rect.top;
    for (const row of this._rows) {
      if (offset >= row.top && offset < row.top + row.height) return row;
    }
    return null;
  }
  dispose() {
    this._detachDoc();
    this._untrackHoverBox();
    this._hoverBoxState = null;
    this._columns = [];
    this._rows = [];
    this.root.remove();
  }
  // ── Internals ────────────────────────────────────────────────────────────
  _ctxFor(row, data) {
    return {
      hovered: row.key === this._hoverKey,
      active: row.key === this._activeKey,
      data
    };
  }
  _applyHover(key) {
    if (key === this._hoverKey) return;
    this._hoverKey = key;
    this._applyHoverToCells();
    this._syncHoverBox(true);
  }
  _applyHoverToCells() {
    var _a2;
    for (const state of this._columns) {
      for (const row of this._rows) {
        const cell = state.cells.get(row.key);
        if (!cell) continue;
        cell.classList.toggle("eg-cell--hover", row.key === this._hoverKey);
        cell.classList.toggle("eg-cell--active", row.key === this._activeKey);
        const data = (_a2 = this._dataFor) == null ? void 0 : _a2.call(this, row.key);
        state.column.update(cell, row, this._ctxFor(row, data));
      }
    }
  }
  /** Paint (or clear) the unified highlight box across the highlightable
   * columns for the hovered row. */
  _syncHoverBox(force) {
    var _a2, _b;
    if (!this._hoverBox) return;
    let box = this.root.querySelector(".eg-hoverbox");
    if (this._hoverKey === null) {
      if (box && (force || box.style.display !== "none")) box.style.display = "none";
      return;
    }
    const row = this._rows.find((r2) => r2.key === this._hoverKey);
    if (!row) {
      if (box) box.style.display = "none";
      return;
    }
    if (!box) {
      box = document.createElement("div");
      box.className = "eg-hoverbox";
      box.style.display = "none";
      box.style.position = "fixed";
      this.root.appendChild(box);
      this._trackHoverBox(box);
    }
    let lastHighlightable = -1;
    this._columns.forEach((state, index) => {
      var _a3, _b2;
      if (((_b2 = (_a3 = state.column).visible) == null ? void 0 : _b2.call(_a3)) === false) return;
      if (this._columnHighlightable(state, row)) lastHighlightable = index;
    });
    if (lastHighlightable < 0) {
      if (box) box.style.display = "none";
      return;
    }
    let width = 0;
    for (let i3 = 0; i3 <= lastHighlightable; i3++) {
      if (((_b = (_a2 = this._columns[i3].column).visible) == null ? void 0 : _b.call(_a2)) === false) continue;
      width += this._columns[i3].column.width();
    }
    box.style.display = "";
    const gr = this.root.getBoundingClientRect();
    const topOverlap = row.top === 0 ? 1 : 0;
    box.style.left = `${gr.left - 1}px`;
    box.style.top = `${gr.top + row.top - topOverlap}px`;
    box.style.width = `${width + 1}px`;
    box.style.height = `${row.height + topOverlap}px`;
    this._hoverBoxState = { row, width, topOverlap };
  }
  _columnHighlightable(state, row) {
    var _a2;
    const fn = state.column.highlightable;
    return fn ? fn(row, (_a2 = this._dataFor) == null ? void 0 : _a2.call(this, row.key)) : true;
  }
  _trackHoverBox(box) {
    if (this._hoverBoxRaf) return;
    const loop = () => {
      const s2 = this._hoverBoxState;
      if (box.isConnected && s2) {
        const gr = this.root.getBoundingClientRect();
        box.style.left = `${gr.left - 1}px`;
        box.style.top = `${gr.top + s2.row.top - s2.topOverlap}px`;
        box.style.width = `${s2.width + 1}px`;
        box.style.height = `${s2.row.height + s2.topOverlap}px`;
      }
      this._hoverBoxRaf = requestAnimationFrame(loop);
    };
    this._hoverBoxRaf = requestAnimationFrame(loop);
  }
  _untrackHoverBox() {
    if (this._hoverBoxRaf) {
      cancelAnimationFrame(this._hoverBoxRaf);
      this._hoverBoxRaf = 0;
    }
  }
  _onCellMousedown(state, row, event) {
    var _a2, _b;
    if (event.button !== 0) return;
    if (!this._columnHighlightable(state, row)) return;
    event.preventDefault();
    event.stopPropagation();
    this._anchor = row;
    this._dragStartX = event.clientX;
    this._dragStartY = event.clientY;
    this._dragMoved = false;
    this._dragging = true;
    (_b = (_a2 = this._events).onRowClick) == null ? void 0 : _b.call(_a2, row);
    this._detachDoc();
    const move = (e2) => this._onDocMove(e2);
    const up = () => this._onDocUp();
    document.addEventListener("mousemove", move);
    document.addEventListener("mouseup", up);
    this._disposeDoc = () => {
      document.removeEventListener("mousemove", move);
      document.removeEventListener("mouseup", up);
    };
  }
  _onDocMove(event) {
    var _a2, _b;
    if (!this._dragging || !this._anchor) return;
    const dx = Math.abs(event.clientX - this._dragStartX);
    const dy = Math.abs(event.clientY - this._dragStartY);
    if (!this._dragMoved && dx + dy < DRAG_THRESHOLD_PX) return;
    if ((event.buttons & 1) !== 1) {
      this._endDrag();
      return;
    }
    this._dragMoved = true;
    const row = this.rowAtClientY(event.clientY);
    if (row && row.key !== this._anchor.key) {
      (_b = (_a2 = this._events).onRowSelectRange) == null ? void 0 : _b.call(_a2, this._anchor, row);
    }
  }
  _onDocUp() {
    this._endDrag();
  }
  _endDrag() {
    this._dragging = false;
    this._dragMoved = false;
    this._anchor = null;
    this._detachDoc();
  }
  _detachDoc() {
    if (this._disposeDoc) {
      this._disposeDoc();
      this._disposeDoc = null;
    }
  }
}
const GUTTER_DEFAULT_CSS = (
  /* css */
  `
  .eg-col {
    box-sizing: border-box;
    flex: 0 0 auto;
  }
  .eg-cell {
    display: flex;
    align-items: center;
    box-sizing: border-box;
    overflow: hidden;
    white-space: nowrap;
  }
  /* Fold-header rows: the chevron button fills the cell and owns its hover. */
  .eg-cell--fold {
    justify-content: center;
    padding: 0;
    cursor: default;
  }
  .eg-fold-chevron {
    border: none;
    background: transparent;
    color: var(--eg-fold-color, #79c0ff);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    flex: 1 1 auto;
    padding: 0;
    box-sizing: border-box;
  }
  .eg-chevron {
    display: block;
  }
  .eg-fold-chevron:hover {
    background: var(--eg-fold-hover-bg, rgba(121, 192, 255, 0.18));
    color: var(--eg-fold-hover-color, #a5d6ff);
    /* Inset ring on hover so the collapse icon reads as a highlighted box
     * (like the unified hover box). */
    box-shadow: inset 0 0 0 1px var(--eg-hover-ring, rgba(255, 255, 255, 0.16));
  }
  /* Unified hover box: spans the highlightable columns on non-foldable rows,
     but stays on the line-number cell only when the row has a chevron (the
     chevron button owns its own hover). Painted by the gutter host; lets
     pointer events pass through. */
  .eg-hoverbox {
    position: absolute;
    left: 0;
    top: 0;
    z-index: 3;
    background: var(--eg-hover-fill, rgba(255, 255, 255, 0.09));
    box-sizing: border-box;
    box-shadow: inset 0 0 0 1px var(--eg-hover-ring, rgba(255, 255, 255, 0.16));
    pointer-events: none;
  }
`
);
function lineNumberColumn(opts) {
  const width = resolveWidth$1(opts.width);
  const errorClass = opts.errorClass ?? "eg-cell--err";
  return {
    id: "line-numbers",
    width,
    highlightable: () => true,
    create() {
      const cell = document.createElement("div");
      cell.className = "eg-cell";
      return cell;
    },
    update(cell, row, ctx) {
      var _a2;
      const label = String(row.key + 1);
      if (cell.textContent !== label) cell.textContent = label;
      const err = !!((_a2 = ctx.data) == null ? void 0 : _a2.error);
      cell.classList.toggle(errorClass, err);
    }
  };
}
function resolveWidth$1(width) {
  return typeof width === "function" ? width : () => width;
}
function foldColumn(opts) {
  const width = resolveWidth(opts.width);
  return {
    id: "fold",
    width,
    highlightable(row, data) {
      return !(data == null ? void 0 : data.hasChevron);
    },
    create() {
      const cell = document.createElement("div");
      cell.className = "eg-cell";
      return cell;
    },
    update(cell, row, ctx) {
      const data = ctx.data;
      const hasChevron = !!(data == null ? void 0 : data.hasChevron);
      cell.classList.toggle("eg-cell--fold", hasChevron);
      if (!hasChevron) {
        const button2 = cell.querySelector("button.eg-fold-chevron");
        if (button2) button2.remove();
        return;
      }
      let button = cell.querySelector("button.eg-fold-chevron");
      if (!button) {
        button = document.createElement("button");
        button.className = "eg-fold-chevron";
        button.addEventListener("click", () => {
          var _a2;
          return (_a2 = opts.onToggle) == null ? void 0 : _a2.call(opts, row.key);
        });
        cell.appendChild(button);
      }
      const folded = !!(data == null ? void 0 : data.folded);
      const points = folded ? "6,4 10,8 6,12" : "4,6 8,10 12,6";
      button.title = folded ? "Expand" : "Collapse";
      const svg = button.querySelector("svg.eg-chevron");
      if (svg) {
        const polyline = svg.querySelector("polyline");
        if (polyline && polyline.getAttribute("points") !== points) {
          polyline.setAttribute("points", points);
        }
      } else {
        button.replaceChildren();
        const svgEl = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        svgEl.setAttribute("class", "eg-chevron");
        svgEl.setAttribute("viewBox", "0 0 16 16");
        svgEl.setAttribute("width", "12");
        svgEl.setAttribute("height", "12");
        svgEl.setAttribute("fill", "none");
        svgEl.setAttribute("stroke", "currentColor");
        svgEl.setAttribute("stroke-width", "1.5");
        svgEl.setAttribute("stroke-linecap", "round");
        svgEl.setAttribute("stroke-linejoin", "round");
        const polyline = document.createElementNS("http://www.w3.org/2000/svg", "polyline");
        polyline.setAttribute("points", points);
        svgEl.appendChild(polyline);
        button.appendChild(svgEl);
      }
    }
  };
}
function resolveWidth(width) {
  return typeof width === "function" ? width : () => width;
}
function isSelectionNonEmpty(selection) {
  return !(selection.selectionStartLineNumber === selection.positionLineNumber && selection.selectionStartColumn === selection.positionColumn);
}
function selectionRange(selection) {
  if (selection.selectionStartLineNumber < selection.positionLineNumber || selection.selectionStartLineNumber === selection.positionLineNumber && selection.selectionStartColumn <= selection.positionColumn) {
    return {
      startLineNumber: selection.selectionStartLineNumber,
      startColumn: selection.selectionStartColumn,
      endLineNumber: selection.positionLineNumber,
      endColumn: selection.positionColumn
    };
  }
  return {
    startLineNumber: selection.positionLineNumber,
    startColumn: selection.positionColumn,
    endLineNumber: selection.selectionStartLineNumber,
    endColumn: selection.selectionStartColumn
  };
}
function isWhitespace(ch) {
  return ch === 32 || ch === 9;
}
function isWordSeparator(ch) {
  return ch === 40 || ch === 41 || ch === 46 || ch === 44 || ch === 59 || ch === 58 || ch === 91 || ch === 93 || ch === 123 || ch === 125 || ch === 34 || ch === 39 || ch === 96;
}
function findWordBounds(model, lineNumber, column) {
  const lineContent = model.getLineContent(lineNumber);
  const lineLen = lineContent.length;
  if (lineLen === 0) return null;
  let allWhitespace = true;
  for (let i3 = 0; i3 < lineLen; i3++) {
    const ch2 = lineContent.charCodeAt(i3);
    if (!isWhitespace(ch2)) {
      allWhitespace = false;
      break;
    }
  }
  if (allWhitespace) return null;
  const clampedCol = Math.max(1, Math.min(column, lineLen + 1));
  const index = clampedCol - 1;
  if (index >= lineLen) {
    return findLastWord(lineContent, lineLen);
  }
  const ch = lineContent.charCodeAt(index);
  if (isWhitespace(ch)) {
    for (let i3 = index - 1; i3 >= 0; i3--) {
      const c2 = lineContent.charCodeAt(i3);
      if (!isWhitespace(c2) && !isWordSeparator(c2)) {
        return findWordBoundsAtPosition(lineContent, i3);
      }
    }
    for (let i3 = index + 1; i3 < lineLen; i3++) {
      const c2 = lineContent.charCodeAt(i3);
      if (!isWhitespace(c2) && !isWordSeparator(c2)) {
        return findWordBoundsAtPosition(lineContent, i3);
      }
    }
    return null;
  }
  if (isWordSeparator(ch)) {
    return { start: clampedCol, end: clampedCol + 1 };
  }
  return findWordBoundsAtPosition(lineContent, index);
}
function findLastWord(lineContent, lineLen) {
  for (let i3 = lineLen - 1; i3 >= 0; i3--) {
    const c2 = lineContent.charCodeAt(i3);
    if (!isWhitespace(c2) && !isWordSeparator(c2)) {
      return findWordBoundsAtPosition(lineContent, i3);
    }
  }
  return null;
}
function findWordBoundsAtPosition(lineContent, index) {
  let start = index;
  while (start > 0) {
    const ch = lineContent.charCodeAt(start - 1);
    if (isWhitespace(ch) || isWordSeparator(ch)) break;
    start--;
  }
  let end = index + 1;
  while (end < lineContent.length) {
    const ch = lineContent.charCodeAt(end);
    if (isWhitespace(ch) || isWordSeparator(ch)) break;
    end++;
  }
  return { start: start + 1, end: end + 1 };
}
function moveLeft(model, position) {
  if (position.column > 1) {
    return { lineNumber: position.lineNumber, column: position.column - 1 };
  }
  if (position.lineNumber > 1) {
    const prevLine = model.getLineContent(position.lineNumber - 1);
    return { lineNumber: position.lineNumber - 1, column: prevLine.length + 1 };
  }
  return position;
}
function moveRight(model, position) {
  const lineLen = model.getLineContent(position.lineNumber).length;
  if (position.column <= lineLen) {
    return { lineNumber: position.lineNumber, column: position.column + 1 };
  }
  if (position.lineNumber < model.lineCount) {
    return { lineNumber: position.lineNumber + 1, column: 1 };
  }
  return position;
}
function moveUp(model, position, goalColumn, coordinatesConverter) {
  const goal = goalColumn ?? position.column;
  if (coordinatesConverter == null ? void 0 : coordinatesConverter.isWordWrap) {
    const viewPos = coordinatesConverter.convertModelToViewPosition(
      position.lineNumber,
      position.column
    );
    if (viewPos.lineNumber <= 1) {
      return { position: { lineNumber: 1, column: 1 }, goalColumn: goal };
    }
    const newViewPos = {
      lineNumber: viewPos.lineNumber - 1,
      column: viewPos.column
    };
    const modelPos = coordinatesConverter.convertViewToModelPosition(
      newViewPos.lineNumber,
      newViewPos.column
    );
    if (modelPos.lineNumber !== position.lineNumber) {
      const lineLen = model.getLineContent(modelPos.lineNumber).length;
      return {
        position: { lineNumber: modelPos.lineNumber, column: Math.min(goal, lineLen + 1) },
        goalColumn: goal
      };
    }
    return { position: modelPos, goalColumn: goal };
  }
  if (position.lineNumber <= 1) return { position, goalColumn: goal };
  const prevLine = model.getLineContent(position.lineNumber - 1);
  const targetCol = Math.min(goal, prevLine.length + 1);
  return {
    position: { lineNumber: position.lineNumber - 1, column: targetCol },
    goalColumn: goal
  };
}
function moveDown(model, position, goalColumn, coordinatesConverter) {
  const goal = goalColumn ?? position.column;
  if (coordinatesConverter == null ? void 0 : coordinatesConverter.isWordWrap) {
    const viewPos = coordinatesConverter.convertModelToViewPosition(
      position.lineNumber,
      position.column
    );
    const totalViewLines = coordinatesConverter.getTotalViewLineCount();
    if (viewPos.lineNumber >= totalViewLines) {
      const lastModelLine = model.lineCount;
      const lastLineLen = model.getLineContent(lastModelLine).length;
      return {
        position: { lineNumber: lastModelLine, column: lastLineLen + 1 },
        goalColumn: goal
      };
    }
    const newViewPos = {
      lineNumber: viewPos.lineNumber + 1,
      column: viewPos.column
    };
    const modelPos = coordinatesConverter.convertViewToModelPosition(
      newViewPos.lineNumber,
      newViewPos.column
    );
    if (modelPos.lineNumber !== position.lineNumber) {
      const lineLen = model.getLineContent(modelPos.lineNumber).length;
      return {
        position: { lineNumber: modelPos.lineNumber, column: Math.min(goal, lineLen + 1) },
        goalColumn: goal
      };
    }
    return { position: modelPos, goalColumn: goal };
  }
  if (position.lineNumber >= model.lineCount) return { position, goalColumn: goal };
  const nextLine = model.getLineContent(position.lineNumber + 1);
  const targetCol = Math.min(goal, nextLine.length + 1);
  return {
    position: { lineNumber: position.lineNumber + 1, column: targetCol },
    goalColumn: goal
  };
}
function moveToLineStart(_model, position) {
  return { lineNumber: position.lineNumber, column: 1 };
}
function moveToLineEnd(model, position) {
  const lineLen = model.getLineContent(position.lineNumber).length;
  return { lineNumber: position.lineNumber, column: lineLen + 1 };
}
function moveWordLeft(model, position) {
  const lineContent = model.getLineContent(position.lineNumber);
  let col = position.column - 1;
  while (col > 0 && isWhitespace(lineContent.charCodeAt(col - 1))) {
    col--;
  }
  while (col > 0 && !isWhitespace(lineContent.charCodeAt(col - 1)) && !isWordSeparator(lineContent.charCodeAt(col - 1))) {
    col--;
  }
  if (col > 0 && isWordSeparator(lineContent.charCodeAt(col - 1))) {
    return { lineNumber: position.lineNumber, column: col };
  }
  if (col === 0 && position.lineNumber > 1) {
    const prevLine = model.getLineContent(position.lineNumber - 1);
    return { lineNumber: position.lineNumber - 1, column: prevLine.length + 1 };
  }
  return { lineNumber: position.lineNumber, column: col + 1 };
}
function moveWordRight(model, position) {
  const lineContent = model.getLineContent(position.lineNumber);
  let col = position.column - 1;
  const lineLen = lineContent.length;
  while (col < lineLen && isWhitespace(lineContent.charCodeAt(col))) {
    col++;
  }
  if (col < lineLen) {
    const ch = lineContent.charCodeAt(col);
    if (isWordSeparator(ch)) {
      while (col < lineLen && isWordSeparator(lineContent.charCodeAt(col))) {
        col++;
      }
    } else {
      while (col < lineLen && !isWhitespace(lineContent.charCodeAt(col)) && !isWordSeparator(lineContent.charCodeAt(col))) {
        col++;
      }
    }
  }
  if (col >= lineLen && position.lineNumber < model.lineCount) {
    return { lineNumber: position.lineNumber + 1, column: 1 };
  }
  return { lineNumber: position.lineNumber, column: col + 1 };
}
function movePageUp(model, position, visibleLineCount) {
  const targetLine = Math.max(1, position.lineNumber - visibleLineCount);
  const line = model.getLineContent(targetLine);
  return { lineNumber: targetLine, column: Math.min(position.column, line.length + 1) };
}
function movePageDown(model, position, visibleLineCount) {
  const targetLine = Math.min(model.lineCount, position.lineNumber + visibleLineCount);
  const line = model.getLineContent(targetLine);
  return { lineNumber: targetLine, column: Math.min(position.column, line.length + 1) };
}
class CursorController {
  constructor(model) {
    __publicField(this, "_model");
    __publicField(this, "_cursor");
    __publicField(this, "_secondaryCursors", []);
    __publicField(this, "_onDidChange", null);
    __publicField(this, "_visibleLineCount", 30);
    __publicField(this, "_coordinatesConverter", null);
    this._model = model;
    this._cursor = {
      position: { lineNumber: 1, column: 1 },
      selectionAnchor: { lineNumber: 1, column: 1 },
      goalColumn: 1
    };
  }
  get position() {
    return this._cursor.position;
  }
  get selection() {
    return {
      selectionStartLineNumber: this._cursor.selectionAnchor.lineNumber,
      selectionStartColumn: this._cursor.selectionAnchor.column,
      positionLineNumber: this._cursor.position.lineNumber,
      positionColumn: this._cursor.position.column
    };
  }
  get cursorState() {
    return { ...this._cursor };
  }
  getAllCursors() {
    return [this._cursor, ...this._secondaryCursors];
  }
  get cursorCount() {
    return 1 + this._secondaryCursors.length;
  }
  get hasMultipleCursors() {
    return this._secondaryCursors.length > 0;
  }
  setVisibleLineCount(count) {
    this._visibleLineCount = count;
  }
  set onDidChange(handler) {
    this._onDidChange = handler;
  }
  /**
   * Set the coordinates converter for word-wrap-aware movement.
   */
  setCoordinatesConverter(converter) {
    this._coordinatesConverter = converter;
  }
  get model() {
    return this._model;
  }
  // ── Multi-cursor ──
  addCursor(position) {
    if (this._cursor.position.lineNumber === position.lineNumber && this._cursor.position.column === position.column)
      return;
    for (const c2 of this._secondaryCursors) {
      if (c2.position.lineNumber === position.lineNumber && c2.position.column === position.column)
        return;
    }
    this._secondaryCursors.push({
      position: { ...position },
      selectionAnchor: { ...position },
      goalColumn: position.column
    });
    this._emit("multi-cursor");
  }
  addCursorAt(lineNumber, column) {
    this.addCursor({ lineNumber, column });
  }
  /** Add a cursor one line above the primary cursor. */
  addCursorAbove() {
    const pos = this._cursor.position;
    if (pos.lineNumber > 1) {
      this.addCursor({ lineNumber: pos.lineNumber - 1, column: pos.column });
    }
  }
  /** Add a cursor one line below the primary cursor. */
  addCursorBelow() {
    const pos = this._cursor.position;
    if (pos.lineNumber < this._model.lineCount) {
      this.addCursor({ lineNumber: pos.lineNumber + 1, column: pos.column });
    }
  }
  /** Add cursors at the start of each line in the current selection. */
  addCursorsToSelectionLines() {
    const sel = this.selection;
    const startLine = Math.min(sel.selectionStartLineNumber, sel.positionLineNumber);
    const endLine = Math.max(sel.selectionStartLineNumber, sel.positionLineNumber);
    this.removeSecondaryCursors();
    for (let line = startLine; line <= endLine; line++) {
      this.addCursor({ lineNumber: line, column: 1 });
    }
    this._emit("multi-cursor");
  }
  removeSecondaryCursors() {
    if (this._secondaryCursors.length === 0) return;
    this._secondaryCursors = [];
    this._emit("multi-cursor");
  }
  addCursorsToLineEnds() {
    const sel = this.selection;
    const startLine = Math.min(sel.selectionStartLineNumber, sel.positionLineNumber);
    const endLine = Math.max(sel.selectionStartLineNumber, sel.positionLineNumber);
    this.removeSecondaryCursors();
    for (let line = startLine; line <= endLine; line++) {
      const lineLen = this._model.getLineContent(line).length;
      this.addCursor({ lineNumber: line, column: lineLen + 1 });
    }
    const lastLineLen = this._model.getLineContent(endLine).length;
    this._cursor.position = { lineNumber: endLine, column: lastLineLen + 1 };
    this._cursor.selectionAnchor = this._cursor.position;
    this._emit("multi-cursor");
  }
  /**
   * Add a cursor at the next occurrence of the currently selected text.
   * If no text is selected, this is a no-op.
   */
  addSelectionToNextFindMatch() {
    const sel = this.selection;
    if (!isSelectionNonEmpty(sel)) return;
    const selectedText = this._model.getValueInRange({
      startLineNumber: Math.min(sel.selectionStartLineNumber, sel.positionLineNumber),
      startColumn: Math.min(sel.selectionStartColumn, sel.positionColumn),
      endLineNumber: Math.max(sel.selectionStartLineNumber, sel.positionLineNumber),
      endColumn: Math.max(sel.selectionStartColumn, sel.positionColumn)
    });
    if (selectedText.length === 0) return;
    const endOffset = this._model.getOffsetAt({
      lineNumber: Math.max(sel.selectionStartLineNumber, sel.positionLineNumber),
      column: Math.max(sel.selectionStartColumn, sel.positionColumn)
    });
    const fullText = this._model.getValue();
    const nextIndex = fullText.indexOf(selectedText, endOffset + 1);
    if (nextIndex >= 0) {
      const pos = this._model.getPositionAt(nextIndex);
      const endPos = this._model.getPositionAt(nextIndex + selectedText.length);
      this.addCursor(pos);
      const newCursor = this._secondaryCursors[this._secondaryCursors.length - 1];
      if (newCursor) {
        newCursor.selectionAnchor = pos;
        newCursor.position = endPos;
      }
    }
  }
  /**
   * Add cursors at all occurrences of the currently selected text.
   */
  selectAllOccurrences() {
    const sel = this.selection;
    if (!isSelectionNonEmpty(sel)) return;
    const selectedText = this._model.getValueInRange({
      startLineNumber: Math.min(sel.selectionStartLineNumber, sel.positionLineNumber),
      startColumn: Math.min(sel.selectionStartColumn, sel.positionColumn),
      endLineNumber: Math.max(sel.selectionStartLineNumber, sel.positionLineNumber),
      endColumn: Math.max(sel.selectionStartColumn, sel.positionColumn)
    });
    if (selectedText.length === 0) return;
    this.removeSecondaryCursors();
    const fullText = this._model.getValue();
    let searchOffset = 0;
    let firstFound = true;
    while (true) {
      const index = fullText.indexOf(selectedText, searchOffset);
      if (index < 0) break;
      const pos = this._model.getPositionAt(index);
      const endPos = this._model.getPositionAt(index + selectedText.length);
      if (firstFound) {
        this._cursor.position = { ...endPos };
        this._cursor.selectionAnchor = { ...pos };
        this._cursor.goalColumn = endPos.column;
        firstFound = false;
      } else {
        this.addCursor(pos);
        const newCursor = this._secondaryCursors[this._secondaryCursors.length - 1];
        if (newCursor) {
          newCursor.selectionAnchor = { ...pos };
          newCursor.position = { ...endPos };
        }
      }
      searchOffset = index + selectedText.length;
    }
  }
  // ── Movement (applies to ALL cursors — compute first, then emit) ──
  moveLeft() {
    const primaryPos = moveLeft(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveLeft(this._model, c2.position)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  moveRight() {
    const primaryPos = moveRight(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveRight(this._model, c2.position)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  moveUp() {
    const cc = this._coordinatesConverter;
    let primaryStart = this._cursor.position;
    let primaryGoal = this._cursor.goalColumn;
    const sel = this.selection;
    if (isSelectionNonEmpty(sel)) {
      const topLine = Math.min(sel.selectionStartLineNumber, sel.positionLineNumber);
      const topCol = sel.selectionStartLineNumber <= sel.positionLineNumber ? sel.selectionStartColumn : sel.positionColumn;
      primaryStart = { lineNumber: topLine, column: topCol };
      primaryGoal = topCol;
    }
    const result = moveUp(this._model, primaryStart, primaryGoal, cc);
    const goalCol = result.goalColumn;
    const primaryPos = result.position;
    const secondaryPositions = this._secondaryCursors.map((c2) => {
      const r2 = moveUp(this._model, c2.position, c2.goalColumn, cc);
      c2.goalColumn = r2.goalColumn;
      return { index: c2, pos: r2.position };
    });
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
    this._cursor.goalColumn = goalCol;
  }
  moveDown() {
    const cc = this._coordinatesConverter;
    let primaryStart = this._cursor.position;
    let primaryGoal = this._cursor.goalColumn;
    const sel = this.selection;
    if (isSelectionNonEmpty(sel)) {
      const bottomLine = Math.max(sel.selectionStartLineNumber, sel.positionLineNumber);
      const bottomCol = sel.selectionStartLineNumber >= sel.positionLineNumber ? sel.selectionStartColumn : sel.positionColumn;
      primaryStart = { lineNumber: bottomLine, column: bottomCol };
      primaryGoal = bottomCol;
    }
    const result = moveDown(this._model, primaryStart, primaryGoal, cc);
    const goalCol = result.goalColumn;
    const primaryPos = result.position;
    const secondaryPositions = this._secondaryCursors.map((c2) => {
      const r2 = moveDown(this._model, c2.position, c2.goalColumn, cc);
      c2.goalColumn = r2.goalColumn;
      return { index: c2, pos: r2.position };
    });
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
    this._cursor.goalColumn = goalCol;
  }
  moveTo(lineNumber, column) {
    const lineCount = this._model.lineCount;
    const clampedLine = Math.max(1, Math.min(lineNumber, lineCount));
    const lineLen = this._model.getLineContent(clampedLine).length;
    const clampedCol = Math.max(1, Math.min(column, lineLen + 1));
    this._cursor.goalColumn = clampedCol;
    this._setPosition({ lineNumber: clampedLine, column: clampedCol });
  }
  /**
   * Select the entire content of a line. The cursor ends up at the start
   * of the line with the selection extending to the end of the line.
   */
  selectLine(lineNumber) {
    const lineCount = this._model.lineCount;
    const clampedLine = Math.max(1, Math.min(lineNumber, lineCount));
    const lineLen = this._model.getLineContent(clampedLine).length;
    const startCol = 1;
    const endCol = lineLen + 1;
    this._applyToSecondaryCursors((cursor) => {
      cursor.selectionAnchor = { lineNumber: clampedLine, column: startCol };
      cursor.position = { lineNumber: clampedLine, column: endCol };
      cursor.goalColumn = endCol;
    });
    this._cursor.selectionAnchor = { lineNumber: clampedLine, column: startCol };
    this._cursor.position = { lineNumber: clampedLine, column: endCol };
    this._cursor.goalColumn = endCol;
    this._emit("selection-changed");
  }
  /**
   * Select the word at the given position.
   * Expands left and right to word boundaries (whitespace/separator).
   * On empty lines, moves cursor to column 1 with no selection.
   */
  selectWordAt(position) {
    const bounds = findWordBounds(this._model, position.lineNumber, position.column);
    if (!bounds) {
      this._setPosition({ lineNumber: position.lineNumber, column: 1 });
      return;
    }
    this._cursor.selectionAnchor = {
      lineNumber: position.lineNumber,
      column: bounds.start
    };
    this._cursor.position = {
      lineNumber: position.lineNumber,
      column: bounds.end
    };
    this._cursor.goalColumn = bounds.end;
    this._emit("selection-changed");
  }
  moveToLineStart() {
    const primaryPos = moveToLineStart(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveToLineStart(this._model, c2.position)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  moveToLineEnd() {
    const primaryPos = moveToLineEnd(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveToLineEnd(this._model, c2.position)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  moveToFileStart() {
    const pos = { lineNumber: 1, column: 1 };
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: { ...pos }
    }));
    for (const { index: c2, pos: p2 } of secondaryPositions) {
      c2.position = p2;
      c2.selectionAnchor = { ...p2 };
    }
    this._setPosition(pos);
  }
  moveToFileEnd() {
    const lastLine = this._model.lineCount;
    const lastLineLen = this._model.getLineContent(lastLine).length;
    const pos = { lineNumber: lastLine, column: lastLineLen + 1 };
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: { ...pos }
    }));
    for (const { index: c2, pos: p2 } of secondaryPositions) {
      c2.position = p2;
      c2.selectionAnchor = { ...p2 };
    }
    this._setPosition(pos);
  }
  moveWordLeft() {
    const primaryPos = moveWordLeft(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveWordLeft(this._model, c2.position)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  moveWordRight() {
    const primaryPos = moveWordRight(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveWordRight(this._model, c2.position)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  movePageUp() {
    const primaryPos = movePageUp(this._model, this._cursor.position, this._visibleLineCount);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: movePageUp(this._model, c2.position, this._visibleLineCount)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  movePageDown() {
    const primaryPos = movePageDown(this._model, this._cursor.position, this._visibleLineCount);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: movePageDown(this._model, c2.position, this._visibleLineCount)
    }));
    for (const { index: c2, pos } of secondaryPositions) {
      c2.position = pos;
      c2.selectionAnchor = { ...pos };
    }
    this._setPosition(primaryPos);
  }
  // ── Selection (applies to ALL cursors) ──
  selectLeft() {
    const primaryPos = moveLeft(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveLeft(this._model, c2.position)
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectRight() {
    const primaryPos = moveRight(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveRight(this._model, c2.position)
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectUp() {
    const cc = this._coordinatesConverter;
    const result = moveUp(this._model, this._cursor.position, this._cursor.goalColumn, cc);
    const goalCol = result.goalColumn;
    const primaryPos = result.position;
    const secondaryPositions = this._secondaryCursors.map((c2) => {
      const r2 = moveUp(this._model, c2.position, c2.goalColumn, cc);
      c2.goalColumn = r2.goalColumn;
      return { index: c2, pos: r2.position };
    });
    this._cursor.goalColumn = goalCol;
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectDown() {
    const cc = this._coordinatesConverter;
    const result = moveDown(this._model, this._cursor.position, this._cursor.goalColumn, cc);
    const goalCol = result.goalColumn;
    const primaryPos = result.position;
    const secondaryPositions = this._secondaryCursors.map((c2) => {
      const r2 = moveDown(this._model, c2.position, c2.goalColumn, cc);
      c2.goalColumn = r2.goalColumn;
      return { index: c2, pos: r2.position };
    });
    this._cursor.goalColumn = goalCol;
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectToLineStart() {
    const primaryPos = moveToLineStart(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveToLineStart(this._model, c2.position)
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectToLineEnd() {
    const primaryPos = moveToLineEnd(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveToLineEnd(this._model, c2.position)
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectToFileStart() {
    const primaryPos = { lineNumber: 1, column: 1 };
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: { lineNumber: 1, column: 1 }
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectToFileEnd() {
    const ll = this._model.lineCount;
    const lll = this._model.getLineContent(ll).length;
    const endPos = { lineNumber: ll, column: lll + 1 };
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: { ...endPos }
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(endPos);
  }
  selectWordLeft() {
    const primaryPos = moveWordLeft(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveWordLeft(this._model, c2.position)
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectWordRight() {
    const primaryPos = moveWordRight(this._model, this._cursor.position);
    const secondaryPositions = this._secondaryCursors.map((c2) => ({
      index: c2,
      pos: moveWordRight(this._model, c2.position)
    }));
    this._applySecondarySelectionPositions(secondaryPositions);
    this._moveSelectionTo(primaryPos);
  }
  selectAll() {
    const lineCount = this._model.lineCount;
    const lastLine = this._model.getLineContent(lineCount);
    const endCol = lastLine.length + 1;
    const anchor = { lineNumber: 1, column: 1 };
    const end = { lineNumber: lineCount, column: endCol };
    this._applyToSecondaryCursors((cursor) => {
      cursor.selectionAnchor = { ...anchor };
      cursor.position = { ...end };
      cursor.goalColumn = endCol;
    });
    this._cursor.selectionAnchor = anchor;
    this._cursor.position = end;
    this._cursor.goalColumn = endCol;
    this._emit("selection-changed");
  }
  /**
   * Replace all cursor states (primary + secondaries), preserving any
   * selections — including multiple cursors at the same position.
   *
   * Used by hosts that maintain their own coordinate model (e.g. a folding
   * editor whose visible buffer maps to a shared text model) to seed the
   * controller with their caret state before delegating a movement/selection
   * command, and by hosts restoring cursor state after the model changes.
   */
  setCursorStates(states) {
    if (states.length === 0) return;
    const first = states[0];
    this._cursor = {
      position: { ...first.position },
      selectionAnchor: { ...first.selectionAnchor },
      goalColumn: first.position.column
    };
    this._secondaryCursors = states.slice(1).map((s2) => ({
      position: { ...s2.position },
      selectionAnchor: { ...s2.selectionAnchor },
      goalColumn: s2.position.column
    }));
    this._emit(states.length > 1 ? "multi-cursor" : "selection-changed");
  }
  /**
   * Move the cursor position to (lineNumber, column) without changing the
   * selection anchor. This extends or shrinks the current selection.
   * Used for mouse-driven text selection (click and drag).
   */
  selectTo(lineNumber, column) {
    const lineCount = this._model.lineCount;
    const clampedLine = Math.max(1, Math.min(lineNumber, lineCount));
    const lineLen = this._model.getLineContent(clampedLine).length;
    const clampedCol = Math.max(1, Math.min(column, lineLen + 1));
    this._cursor.goalColumn = clampedCol;
    this._moveSelectionTo({ lineNumber: clampedLine, column: clampedCol });
  }
  // ── Editing (applies to ALL cursors) ──
  _captureCursorState() {
    const allCursors = this.getAllCursors();
    this._model.setBeforeEditCursorState(
      allCursors.map((c2) => {
        var _a2, _b;
        return {
          selectionStartLineNumber: ((_a2 = c2.selectionAnchor) == null ? void 0 : _a2.lineNumber) ?? c2.position.lineNumber,
          selectionStartColumn: ((_b = c2.selectionAnchor) == null ? void 0 : _b.column) ?? c2.position.column,
          positionLineNumber: c2.position.lineNumber,
          positionColumn: c2.position.column
        };
      })
    );
  }
  insertChar(char) {
    this._captureCursorState();
    const allCursors = this.getAllCursors();
    const edits = allCursors.map((c2) => {
      const sel = this._getSelectionOrNullFor(c2);
      const range = sel && isSelectionNonEmpty(sel) ? selectionRange(sel) : {
        startLineNumber: c2.position.lineNumber,
        startColumn: c2.position.column,
        endLineNumber: c2.position.lineNumber,
        endColumn: c2.position.column
      };
      return { range, text: char };
    });
    this._model.pushEditOperations(edits);
    const newPositions = edits.map((e2) => this._computeNewPosition(e2.range, char));
    this._cursor.position = newPositions[0];
    this._cursor.selectionAnchor = this._cursor.position;
    this._cursor.goalColumn = this._cursor.position.column;
    for (let i3 = 1; i3 < newPositions.length; i3++) {
      const c2 = this._secondaryCursors[i3 - 1];
      if (c2) {
        c2.position = newPositions[i3];
        c2.selectionAnchor = newPositions[i3];
        c2.goalColumn = newPositions[i3].column;
      }
    }
    this._emit("edit");
  }
  insertNewLine() {
    this.insertChar("\n");
  }
  /** Alt/Option+ArrowUp/Down — move the primary cursor's current line up/down
   *  (VS Code). Swaps the line with its neighbor and follows the caret to the
   *  same column on the moved line. */
  moveLine(dir) {
    const line = this._cursor.position.lineNumber;
    const target = line + dir;
    if (target < 1 || target > this._model.lineCount) return;
    const self = this._model.getLineContent(line);
    const other = this._model.getLineContent(target);
    this._captureCursorState();
    const range = dir < 0 ? {
      startLineNumber: target,
      startColumn: 1,
      endLineNumber: line,
      endColumn: self.length + 1
    } : {
      startLineNumber: line,
      startColumn: 1,
      endLineNumber: target,
      endColumn: other.length + 1
    };
    const text = dir < 0 ? `${self}
${other}` : `${other}
${self}`;
    this._model.pushEditOperations([{ range, text }]);
    const newCol = Math.min(this._cursor.position.column, self.length + 1);
    this._cursor.position = { lineNumber: target, column: newCol };
    this._cursor.selectionAnchor = this._cursor.position;
    this._cursor.goalColumn = newCol;
    this._emit("edit");
  }
  insertTab() {
    this._captureCursorState();
    const spaces = "    ";
    const allCursors = this.getAllCursors();
    const edits = allCursors.map((c2) => ({
      range: {
        startLineNumber: c2.position.lineNumber,
        startColumn: c2.position.column,
        endLineNumber: c2.position.lineNumber,
        endColumn: c2.position.column
      },
      text: spaces
    }));
    this._model.pushEditOperations(edits);
    const newPositions = edits.map((e2) => this._computeNewPosition(e2.range, spaces));
    this._cursor.position = newPositions[0];
    this._cursor.selectionAnchor = this._cursor.position;
    this._cursor.goalColumn = this._cursor.position.column;
    for (let i3 = 1; i3 < newPositions.length; i3++) {
      const c2 = this._secondaryCursors[i3 - 1];
      if (c2) {
        c2.position = newPositions[i3];
        c2.selectionAnchor = newPositions[i3];
      }
    }
    this._emit("edit");
  }
  deleteLeft() {
    this._captureCursorState();
    const allCursors = this.getAllCursors();
    const sortedCursors = [...allCursors].sort((a2, b2) => {
      if (a2.position.lineNumber !== b2.position.lineNumber) {
        return b2.position.lineNumber - a2.position.lineNumber;
      }
      return b2.position.column - a2.position.column;
    });
    const edits = sortedCursors.map((c2) => {
      const sel = this._getSelectionOrNullFor(c2);
      if (sel && isSelectionNonEmpty(sel)) {
        const range = selectionRange(sel);
        return { range, text: "" };
      }
      if (c2.position.column === 1 && c2.position.lineNumber > 1) {
        const prevLineLen = this._model.getLineContent(c2.position.lineNumber - 1).length;
        return {
          range: {
            startLineNumber: c2.position.lineNumber - 1,
            startColumn: prevLineLen + 1,
            endLineNumber: c2.position.lineNumber,
            endColumn: 1
          },
          text: ""
        };
      }
      return {
        range: {
          startLineNumber: c2.position.lineNumber,
          startColumn: Math.max(1, c2.position.column - 1),
          endLineNumber: c2.position.lineNumber,
          endColumn: c2.position.column
        },
        text: ""
      };
    });
    const joinColumns = allCursors.map((c2) => {
      if (c2.position.column === 1 && c2.position.lineNumber > 1) {
        return this._model.getLineContent(c2.position.lineNumber - 1).length;
      }
      return void 0;
    });
    this._model.pushEditOperations(edits);
    this._cursor.position = this._computeDeleteLeftPosition(
      allCursors[0].position,
      this._getSelectionOrNullFor(allCursors[0]),
      joinColumns[0]
    );
    this._cursor.selectionAnchor = this._cursor.position;
    this._cursor.goalColumn = this._cursor.position.column;
    for (let i3 = 1; i3 < allCursors.length; i3++) {
      const c2 = this._secondaryCursors[i3 - 1];
      if (c2) {
        c2.position = this._computeDeleteLeftPosition(
          allCursors[i3].position,
          this._getSelectionOrNullFor(allCursors[i3]),
          joinColumns[i3]
        );
        c2.selectionAnchor = c2.position;
      }
    }
    this._emit("edit");
  }
  deleteRight() {
    this._captureCursorState();
    const allCursors = this.getAllCursors();
    const sortedCursors = [...allCursors].sort((a2, b2) => {
      if (a2.position.lineNumber !== b2.position.lineNumber) {
        return b2.position.lineNumber - a2.position.lineNumber;
      }
      return b2.position.column - a2.position.column;
    });
    const edits = sortedCursors.map((c2) => {
      const sel = this._getSelectionOrNullFor(c2);
      if (sel && isSelectionNonEmpty(sel)) {
        const range = selectionRange(sel);
        return { range, text: "" };
      }
      const lineLen = this._model.getLineContent(c2.position.lineNumber).length;
      if (c2.position.column > lineLen && c2.position.lineNumber < this._model.lineCount) {
        return {
          range: {
            startLineNumber: c2.position.lineNumber,
            startColumn: lineLen + 1,
            endLineNumber: c2.position.lineNumber + 1,
            endColumn: 1
          },
          text: ""
        };
      }
      return {
        range: {
          startLineNumber: c2.position.lineNumber,
          startColumn: c2.position.column,
          endLineNumber: c2.position.lineNumber,
          endColumn: Math.min(lineLen + 1, c2.position.column + 1)
        },
        text: ""
      };
    });
    this._model.pushEditOperations(edits);
    this._cursor.position = { ...allCursors[0].position };
    this._cursor.selectionAnchor = this._cursor.position;
    this._cursor.goalColumn = this._cursor.position.column;
    for (let i3 = 1; i3 < allCursors.length; i3++) {
      const c2 = this._secondaryCursors[i3 - 1];
      if (c2) {
        c2.position = { ...allCursors[i3].position };
        c2.selectionAnchor = c2.position;
      }
    }
    this._emit("edit");
  }
  undo() {
    const result = this._model.undo();
    if (result && result.length > 0) {
      const sel = result[0];
      this._cursor.position = { lineNumber: sel.positionLineNumber, column: sel.positionColumn };
      this._cursor.selectionAnchor = {
        lineNumber: sel.selectionStartLineNumber,
        column: sel.selectionStartColumn
      };
      this._cursor.goalColumn = this._cursor.position.column;
      this._secondaryCursors = [];
      for (let i3 = 1; i3 < result.length; i3++) {
        const s2 = result[i3];
        this._secondaryCursors.push({
          position: { lineNumber: s2.positionLineNumber, column: s2.positionColumn },
          selectionAnchor: {
            lineNumber: s2.selectionStartLineNumber,
            column: s2.selectionStartColumn
          },
          goalColumn: s2.positionColumn
        });
      }
      this._emit("undo");
    }
  }
  redo() {
    const result = this._model.redo();
    if (result && result.length > 0) {
      const sel = result[0];
      this._cursor.position = { lineNumber: sel.positionLineNumber, column: sel.positionColumn };
      this._cursor.selectionAnchor = {
        lineNumber: sel.selectionStartLineNumber,
        column: sel.selectionStartColumn
      };
      this._cursor.goalColumn = this._cursor.position.column;
      this._secondaryCursors = [];
      for (let i3 = 1; i3 < result.length; i3++) {
        const s2 = result[i3];
        this._secondaryCursors.push({
          position: { lineNumber: s2.positionLineNumber, column: s2.positionColumn },
          selectionAnchor: {
            lineNumber: s2.selectionStartLineNumber,
            column: s2.selectionStartColumn
          },
          goalColumn: s2.positionColumn
        });
      }
      this._emit("redo");
    }
  }
  // ── Private ──
  _setPosition(position) {
    this._cursor.position = position;
    this._cursor.selectionAnchor = position;
    this._cursor.goalColumn = position.column;
    this._emit("position-changed");
  }
  _moveSelectionTo(position) {
    this._cursor.position = position;
    this._emit("selection-changed");
  }
  _getSelectionOrNull() {
    const sel = this.selection;
    return isSelectionNonEmpty(sel) ? sel : null;
  }
  _getSelectionOrNullFor(cursor) {
    if (cursor.position.lineNumber === cursor.selectionAnchor.lineNumber && cursor.position.column === cursor.selectionAnchor.column)
      return null;
    return {
      selectionStartLineNumber: cursor.selectionAnchor.lineNumber,
      selectionStartColumn: cursor.selectionAnchor.column,
      positionLineNumber: cursor.position.lineNumber,
      positionColumn: cursor.position.column
    };
  }
  _applyToSecondaryCursors(fn) {
    if (this._secondaryCursors.length === 0) return;
    const sorted = [...this._secondaryCursors].sort((a2, b2) => {
      if (a2.position.lineNumber !== b2.position.lineNumber) {
        return b2.position.lineNumber - a2.position.lineNumber;
      }
      return b2.position.column - a2.position.column;
    });
    for (const cursor of sorted) fn(cursor);
  }
  /**
   * Apply computed positions to secondary cursors without emitting.
   * Used by selection methods to update all cursors before the event fires.
   */
  _applySecondarySelectionPositions(positions) {
    for (const { index: c2, pos } of positions) {
      c2.position = pos;
    }
  }
  /**
   * Compute the new cursor position after inserting `text` at `range`.
   */
  _computeNewPosition(range, text) {
    if (text === "") {
      return { lineNumber: range.startLineNumber, column: range.startColumn };
    }
    if (text === "\n") {
      return { lineNumber: range.startLineNumber + 1, column: 1 };
    }
    const lines = text.split("\n");
    if (lines.length > 1) {
      return {
        lineNumber: range.startLineNumber + lines.length - 1,
        column: lines[lines.length - 1].length + 1
      };
    }
    return {
      lineNumber: range.startLineNumber,
      column: range.startColumn + text.length
    };
  }
  /**
   * Compute the new cursor position after a delete-left operation.
   */
  _computeDeleteLeftPosition(cursor, selection, joinColumn) {
    if (selection && isSelectionNonEmpty(selection)) {
      if (selection.selectionStartLineNumber < selection.positionLineNumber || selection.selectionStartLineNumber === selection.positionLineNumber && selection.selectionStartColumn <= selection.positionColumn) {
        return {
          lineNumber: selection.selectionStartLineNumber,
          column: selection.selectionStartColumn
        };
      }
      return {
        lineNumber: selection.positionLineNumber,
        column: selection.positionColumn
      };
    }
    if (cursor.column === 1 && cursor.lineNumber > 1) {
      const prevLineLen = joinColumn ?? this._model.getLineContent(cursor.lineNumber - 1).length;
      return {
        lineNumber: cursor.lineNumber - 1,
        column: prevLineLen + 1
      };
    }
    return {
      lineNumber: cursor.lineNumber,
      column: Math.max(1, cursor.column - 1)
    };
  }
  _emit(type) {
    var _a2;
    (_a2 = this._onDidChange) == null ? void 0 : _a2.call(this, { type });
  }
  dispose() {
    this._onDidChange = null;
  }
}
class TreeNode {
  constructor(piece) {
    __publicField(this, "parent");
    __publicField(this, "left");
    __publicField(this, "right");
    __publicField(this, "color", 0);
    /** Cached: size of left subtree (number of characters / line feeds). */
    __publicField(this, "size_left", 0);
    /** Cached: size of right subtree. */
    __publicField(this, "size_right", 0);
    /** Cached: total line feed count in this node's piece. */
    __publicField(this, "lf_left", 0);
    this.piece = piece;
    this.parent = null;
    this.left = null;
    this.right = null;
  }
}
const SENTINEL = (() => {
  const s2 = new TreeNode(null);
  s2.parent = s2;
  s2.left = s2;
  s2.right = s2;
  s2.color = 1;
  s2.piece = null;
  s2.size_left = 0;
  s2.size_right = 0;
  s2.lf_left = 0;
  return s2;
})();
function initTreeNode(node) {
  node.parent = SENTINEL;
  node.left = SENTINEL;
  node.right = SENTINEL;
}
function updateTreeMetadata(node) {
  const left = node.left;
  const right = node.right;
  node.size_left = left === SENTINEL ? 0 : left.size_left + left.piece.length + left.size_right;
  node.lf_left = left === SENTINEL ? 0 : left.lf_left + left.piece.lineFeedCnt;
  node.size_right = right === SENTINEL ? 0 : right.size_left + right.piece.length + right.size_right;
}
function rotateLeft(tree, x2) {
  const y3 = x2.right;
  x2.right = y3.left;
  if (y3.left !== SENTINEL) {
    y3.left.parent = x2;
  }
  y3.parent = x2.parent;
  if (x2.parent === SENTINEL) {
    tree.root = y3;
  } else if (x2 === x2.parent.left) {
    x2.parent.left = y3;
  } else {
    x2.parent.right = y3;
  }
  y3.left = x2;
  x2.parent = y3;
  updateTreeMetadata(x2);
  updateTreeMetadata(y3);
}
function rotateRight(tree, x2) {
  const y3 = x2.left;
  x2.left = y3.right;
  if (y3.right !== SENTINEL) {
    y3.right.parent = x2;
  }
  y3.parent = x2.parent;
  if (x2.parent === SENTINEL) {
    tree.root = y3;
  } else if (x2 === x2.parent.right) {
    x2.parent.right = y3;
  } else {
    x2.parent.left = y3;
  }
  y3.right = x2;
  x2.parent = y3;
  updateTreeMetadata(x2);
  updateTreeMetadata(y3);
}
function fixInsert(tree, x2) {
  x2.color = 0;
  while (x2 !== tree.root && x2.parent.color === 0) {
    if (x2.parent === x2.parent.parent.left) {
      const y3 = x2.parent.parent.right;
      if (y3.color === 0) {
        x2.parent.color = 1;
        y3.color = 1;
        x2.parent.parent.color = 0;
        x2 = x2.parent.parent;
      } else {
        if (x2 === x2.parent.right) {
          x2 = x2.parent;
          rotateLeft(tree, x2);
        }
        x2.parent.color = 1;
        x2.parent.parent.color = 0;
        rotateRight(tree, x2.parent.parent);
      }
    } else {
      const y3 = x2.parent.parent.left;
      if (y3.color === 0) {
        x2.parent.color = 1;
        y3.color = 1;
        x2.parent.parent.color = 0;
        x2 = x2.parent.parent;
      } else {
        if (x2 === x2.parent.left) {
          x2 = x2.parent;
          rotateRight(tree, x2);
        }
        x2.parent.color = 1;
        x2.parent.parent.color = 0;
        rotateLeft(tree, x2.parent.parent);
      }
    }
  }
  tree.root.color = 1;
}
function findAtOffset(node, offset) {
  let remainder = offset;
  let nodeStartOffset = 0;
  while (node !== SENTINEL) {
    const leftSize = node.size_left;
    if (remainder < leftSize) {
      node = node.left;
    } else {
      remainder -= leftSize;
      nodeStartOffset += leftSize;
      if (remainder < node.piece.length) {
        return { node, remainder, nodeStartOffset };
      }
      remainder -= node.piece.length;
      nodeStartOffset += node.piece.length;
      node = node.right;
    }
  }
  return { node: SENTINEL, remainder: 0, nodeStartOffset: 0 };
}
function findAtLineNumber(node, lineNumber) {
  let lineRemainder = lineNumber;
  let nodeStartLine = 1;
  while (node !== SENTINEL) {
    const leftLf = node.lf_left;
    if (lineRemainder <= leftLf) {
      node = node.left;
    } else {
      lineRemainder -= leftLf;
      nodeStartLine += leftLf;
      if (lineRemainder <= node.piece.lineFeedCnt + 1) {
        return { node, lineRemainder, nodeStartLine };
      }
      lineRemainder -= node.piece.lineFeedCnt + 1;
      nodeStartLine += node.piece.lineFeedCnt + 1;
      node = node.right;
    }
  }
  return { node: SENTINEL, lineRemainder: 1, nodeStartLine: 1 };
}
class Piece {
  constructor(bufferIndex, start, end, lineFeedCnt, length) {
    this.bufferIndex = bufferIndex;
    this.start = start;
    this.end = end;
    this.lineFeedCnt = lineFeedCnt;
    this.length = length;
  }
  /**
   * Create a new Piece that is a sub-range of this piece.
   */
  slice(newStart, newEnd) {
    const newLength = this._measureLength(newStart, newEnd);
    const newLf = this._measureLineFeeds(newStart, newEnd);
    return new Piece(this.bufferIndex, newStart, newEnd, newLf, newLength);
  }
  _measureLength(start, end) {
    if (start.line === end.line) {
      return end.column - start.column;
    }
    return -1;
  }
  _measureLineFeeds(start, end) {
    if (start.line === end.line) {
      return 0;
    }
    return end.line - start.line;
  }
}
var CharCode = /* @__PURE__ */ ((CharCode2) => {
  CharCode2[CharCode2["Tab"] = 9] = "Tab";
  CharCode2[CharCode2["LineFeed"] = 10] = "LineFeed";
  CharCode2[CharCode2["CarriageReturn"] = 13] = "CarriageReturn";
  CharCode2[CharCode2["Space"] = 32] = "Space";
  return CharCode2;
})(CharCode || {});
function createLineStartsFast(str) {
  const r2 = [0];
  let rLength = 1;
  for (let i3 = 0, len = str.length; i3 < len; i3++) {
    const chr = str.charCodeAt(i3);
    if (chr === CharCode.CarriageReturn) {
      if (i3 + 1 < len && str.charCodeAt(i3 + 1) === CharCode.LineFeed) {
        r2[rLength++] = i3 + 2;
        i3++;
      } else {
        r2[rLength++] = i3 + 1;
      }
    } else if (chr === CharCode.LineFeed) {
      r2[rLength++] = i3 + 1;
    }
  }
  return toCompactArray(r2);
}
function toCompactArray(arr) {
  if (arr.length === 0) return arr;
  const max = arr[arr.length - 1];
  if (max < 65536) {
    const r22 = new Uint16Array(arr.length);
    r22.set(arr, 0);
    return r22;
  }
  const r2 = new Uint32Array(arr.length);
  r2.set(arr, 0);
  return r2;
}
class StringBuffer {
  constructor(buffer, lineStarts) {
    this.buffer = buffer;
    this.lineStarts = lineStarts;
  }
  /** Number of lines in this buffer. */
  get lineCount() {
    return this.lineStarts.length;
  }
  /** Total character length of the buffer. */
  get length() {
    return this.buffer.length;
  }
  /**
   * Get the text content of a specific line (0-based).
   * Returns empty string for out-of-range line numbers.
   */
  getLineContent(lineIndex) {
    if (lineIndex < 0 || lineIndex >= this.lineStarts.length) return "";
    const start = this.lineStarts[lineIndex];
    const end = lineIndex + 1 < this.lineStarts.length ? this.lineStarts[lineIndex + 1] : this.buffer.length;
    let actualEnd = end;
    if (actualEnd > start) {
      const lastChar = this.buffer.charCodeAt(actualEnd - 1);
      if (lastChar === CharCode.LineFeed) {
        actualEnd--;
        if (actualEnd > start && this.buffer.charCodeAt(actualEnd - 1) === CharCode.CarriageReturn) {
          actualEnd--;
        }
      } else if (lastChar === CharCode.CarriageReturn) {
        actualEnd--;
      }
    }
    return this.buffer.substring(start, actualEnd);
  }
  /**
   * Get a substring from the buffer.
   */
  getText(start, end) {
    return this.buffer.substring(start, end);
  }
  /**
   * Get a single character at the given offset.
   */
  getCharCode(offset) {
    if (offset < 0 || offset >= this.buffer.length) return 0;
    return this.buffer.charCodeAt(offset);
  }
}
class SearchCache {
  constructor(limit) {
    __publicField(this, "_cache");
    __publicField(this, "_limit");
    this._limit = limit;
    this._cache = [];
  }
  get(offset) {
    for (let i3 = this._cache.length - 1; i3 >= 0; i3--) {
      const entry = this._cache[i3];
      if (entry && entry.nodeStartOffset <= offset && entry.nodeStartOffset + entry.node.piece.length >= offset) {
        return entry;
      }
    }
    return null;
  }
  getByLine(lineNumber) {
    for (let i3 = this._cache.length - 1; i3 >= 0; i3--) {
      const entry = this._cache[i3];
      if (entry && entry.nodeStartLineNumber && entry.nodeStartLineNumber <= lineNumber && entry.nodeStartLineNumber + entry.node.piece.lineFeedCnt >= lineNumber) {
        return entry;
      }
    }
    return null;
  }
  set(entry) {
    if (this._cache.length >= this._limit) {
      this._cache.shift();
    }
    this._cache.push(entry);
  }
  validate(offset) {
    this._cache = this._cache.filter(
      (entry) => entry !== null && entry.node.parent !== null && entry.nodeStartOffset < offset
    );
  }
}
class PieceTreeBase {
  constructor(chunks, eol, eolNormalized) {
    /** The root node of the red-black tree. */
    __publicField(this, "root", SENTINEL);
    /** Array of StringBuffers. Index 0 is the mutable change buffer. */
    __publicField(this, "_buffers", []);
    /** Total number of lines in the document. */
    __publicField(this, "_lineCnt", 1);
    /** Total character length of the document. */
    __publicField(this, "_length", 0);
    /** The EOL sequence used by this document. */
    __publicField(this, "_EOL", "\n");
    /** Length of the EOL sequence. */
    __publicField(this, "_EOLLength", 1);
    /** Whether EOL has been normalized. */
    __publicField(this, "_EOLNormalized", false);
    /** Position tracker for the change buffer. */
    __publicField(this, "_lastChangeBufferPos", { line: 0, column: 0 });
    /** Search cache for fast offset lookups. */
    __publicField(this, "_searchCache", new SearchCache(1));
    /** Cache for the last visited line (avoids repeated tree walks for sequential access). */
    __publicField(this, "_lastVisitedLine", null);
    this.create(chunks, eol, eolNormalized);
  }
  create(chunks, eol, eolNormalized) {
    this._buffers = [new StringBuffer("", [0]), ...chunks];
    this._lastChangeBufferPos = { line: 0, column: 0 };
    this.root = SENTINEL;
    this._lineCnt = 1;
    this._length = 0;
    this._EOL = eol;
    this._EOLLength = eol.length;
    this._EOLNormalized = eolNormalized;
    this._searchCache = new SearchCache(1);
    this._lastVisitedLine = null;
    let lastNode = null;
    for (let i3 = 0, len = chunks.length; i3 < len; i3++) {
      if (chunks[i3].buffer.length > 0) {
        const piece = new Piece(
          i3 + 1,
          // bufferIndex (0 is change buffer, so initial buffers start at 1)
          { line: 0, column: 0 },
          {
            line: chunks[i3].lineCount - 1,
            column: this._getLineLength(chunks[i3], chunks[i3].lineCount - 1)
          },
          chunks[i3].lineCount - 1,
          chunks[i3].buffer.length
        );
        this._insertNode(piece, lastNode);
        lastNode = this.root;
        this._lineCnt += chunks[i3].lineCount - 1;
        this._length += chunks[i3].buffer.length;
      }
    }
    if (this.root !== SENTINEL) {
      this.root.color = 1;
    }
  }
  // ─── Public API ────────────────────────────────────────────────────────────
  getLineCount() {
    return this._lineCnt;
  }
  getLength() {
    return this._length;
  }
  getEOL() {
    return this._EOL;
  }
  setEOL(eol) {
    this._EOL = eol;
    this._EOLLength = eol.length;
  }
  /**
   * Get the text content of a line (1-based).
   */
  getLineContent(lineNumber) {
    if (lineNumber < 1 || lineNumber > this._lineCnt) return "";
    if (this._lastVisitedLine && this._lastVisitedLine.lineNumber === lineNumber) {
      return this._lastVisitedLine.value;
    }
    const pos = this.nodeAt2(lineNumber, 1);
    if (pos.node === SENTINEL) return "";
    this._buffers[pos.node.piece.bufferIndex];
    pos.node.piece;
    if (pos.remainder === 0) {
      return this._getLineFromNode(pos.node, lineNumber);
    }
    const result = this._getLineFromNode(pos.node, lineNumber);
    this._lastVisitedLine = { lineNumber, value: result };
    return result;
  }
  /**
   * Get the text of a range.
   */
  getValueInRange(startLine, startCol, endLine, endCol) {
    if (startLine === endLine && startCol === endCol) return "";
    const startOffset = this.getOffsetAt(startLine, startCol);
    const endOffset = this.getOffsetAt(endLine, endCol);
    return this._getTextFromOffset(startOffset, endOffset - startOffset);
  }
  /**
   * Get the full text of the document.
   */
  getValue(eol) {
    const targetEOL = eol || this._EOL;
    const parts = [];
    if (this.root === SENTINEL) return "";
    this.iterate(this.root, (node) => {
      if (node === SENTINEL) return true;
      const buffer = this._buffers[node.piece.bufferIndex];
      const text = this._getPieceText(node.piece, buffer);
      parts.push(text);
      return true;
    });
    let result = parts.join("");
    if (targetEOL !== "\n") {
      result = result.replace(/\n/g, targetEOL);
    }
    return result;
  }
  /**
   * Get the character offset for a line/column position (1-based).
   */
  getOffsetAt(lineNumber, column) {
    const pos = this.nodeAt2(lineNumber, column);
    if (pos.node === SENTINEL) return this._length;
    const buffer = this._buffers[pos.node.piece.bufferIndex];
    const piece = pos.node.piece;
    const pieceStartOffset = this._getPieceStartOffset(pos.node);
    const lineIdx = piece.start.line + pos.remainder - 1;
    if (lineIdx < 0 || lineIdx >= buffer.lineStarts.length) {
      return pieceStartOffset;
    }
    const lineStartInBuffer = buffer.lineStarts[lineIdx];
    const pieceStartInBuffer = buffer.lineStarts[piece.start.line] + piece.start.column;
    const colInLine = column - 1;
    const lineLen = this._getLineLength(buffer, lineIdx);
    const actualCol = Math.min(colInLine, lineLen);
    const lineOffsetWithinPiece = lineStartInBuffer - pieceStartInBuffer;
    return pieceStartOffset + lineOffsetWithinPiece + actualCol;
  }
  /**
   * Get the line/column position for a character offset (0-based).
   */
  getPositionAt(offset) {
    if (offset < 0) offset = 0;
    if (offset >= this._length) {
      return { lineNumber: this._lineCnt, column: this._getLineLengthAtLine(this._lineCnt) + 1 };
    }
    const pos = this.nodeAt(offset);
    if (pos.node === SENTINEL) {
      return { lineNumber: 1, column: 1 };
    }
    const buffer = this._buffers[pos.node.piece.bufferIndex];
    const piece = pos.node.piece;
    const offsetInPiece = pos.remainder;
    const lineIdx = this._findLineInBuffer(buffer, piece, offsetInPiece);
    const lineStartInBuffer = buffer.lineStarts[lineIdx];
    const pieceStartInBuffer = buffer.lineStarts[piece.start.line] + piece.start.column;
    const colInLine = offsetInPiece - (lineStartInBuffer - pieceStartInBuffer);
    const modelLineNumber = this._getLineNumberForNode(pos.node, pos.nodeStartOffset);
    const lineIndex = pos.nodeStartOffset === void 0 ? 0 : lineIdx - piece.start.line;
    return {
      lineNumber: modelLineNumber + lineIndex,
      column: Math.max(1, colInLine + 1)
    };
  }
  /**
   * Insert text at the given offset.
   */
  insert(offset, text, _incrementBuffer = true) {
    if (text.length === 0) return;
    const normalized = text.replace(/\r\n/g, "\n");
    const before = this._getTextFromOffset(0, offset);
    const after = this._getTextFromOffset(offset, this._length - offset);
    const newText = before + normalized + after;
    this._rebuildTreeFromBuffer(newText);
  }
  /**
   * Delete text at the given offset with the given length.
   */
  delete(offset, length) {
    if (length === 0) return;
    const before = this._getTextFromOffset(0, offset);
    const after = this._getTextFromOffset(offset + length, this._length - offset - length);
    const newText = before + after;
    this._rebuildTreeFromBuffer(newText);
  }
  // ─── Internal helpers ────────────────────────────────────────────────────
  /**
   * Find the node containing the given character offset.
   */
  nodeAt(offset) {
    const cached = this._searchCache.get(offset);
    if (cached) {
      return {
        node: cached.node,
        remainder: offset - cached.nodeStartOffset,
        nodeStartOffset: cached.nodeStartOffset
      };
    }
    const result = findAtOffset(this.root, offset);
    if (result.node !== SENTINEL) {
      this._searchCache.set({ node: result.node, nodeStartOffset: result.nodeStartOffset });
    }
    return result;
  }
  /**
   * Find the node containing the given line/column position.
   */
  nodeAt2(lineNumber, _column) {
    const cached = this._searchCache.getByLine(lineNumber);
    if (cached) {
      const lineOffset = lineNumber - cached.nodeStartLineNumber;
      const node2 = cached.node;
      const buffer = this._buffers[node2.piece.bufferIndex];
      const pieceLineStart = node2.piece.start.line + lineOffset;
      if (pieceLineStart <= node2.piece.end.line) {
        const lineStartInBuffer = buffer.lineStarts[pieceLineStart];
        const pieceStartInBuffer = buffer.lineStarts[node2.piece.start.line];
        const colOffsetInPiece = lineStartInBuffer - pieceStartInBuffer + node2.piece.start.column;
        return {
          node: node2,
          remainder: lineOffset + 1,
          nodeStartOffset: cached.nodeStartOffset + colOffsetInPiece
        };
      }
    }
    const lineResult = findAtLineNumber(this.root, lineNumber);
    if (lineResult.node === SENTINEL) {
      return { node: SENTINEL, remainder: 0, nodeStartOffset: 0 };
    }
    const node = lineResult.node;
    const lineRemainder = lineResult.lineRemainder;
    const offset = this._getOffsetForNodeLine(node, lineResult.nodeStartLine, lineRemainder);
    this._searchCache.set({
      node,
      nodeStartOffset: offset - (lineRemainder - 1),
      nodeStartLineNumber: lineResult.nodeStartLine
    });
    return { node, remainder: lineRemainder, nodeStartOffset: offset };
  }
  /**
   * Iterate tree nodes in-order.
   */
  iterate(node, callback) {
    if (node === SENTINEL) return;
    if (node.left !== SENTINEL) {
      this.iterate(node.left, callback);
    }
    if (!callback(node)) return;
    if (node.right !== SENTINEL) {
      this.iterate(node.right, callback);
    }
  }
  /**
   * Get the text content of a piece from its buffer.
   */
  getPieceContent(piece) {
    const buffer = this._buffers[piece.bufferIndex];
    return this._getPieceText(piece, buffer);
  }
  /**
   * Extract text from a range of the buffer.
   */
  _getPieceText(piece, buffer) {
    const startOffset = buffer.lineStarts[piece.start.line] + piece.start.column;
    const endOffset = buffer.lineStarts[piece.end.line] + piece.end.column;
    return buffer.buffer.substring(startOffset, endOffset);
  }
  /**
   * Get the global offset of the start of a node's piece.
   */
  _getPieceStartOffset(node) {
    let offset = node.size_left;
    let current = node;
    while (current.parent !== SENTINEL) {
      if (current === current.parent.right) {
        offset += current.parent.size_left + current.parent.piece.length;
      }
      current = current.parent;
    }
    return offset;
  }
  /**
   * Insert a node into the tree.
   */
  _insertNode(piece, lastNode) {
    const newNode = new TreeNode(piece);
    initTreeNode(newNode);
    if (this.root === SENTINEL) {
      this.root = newNode;
      this.root.color = 1;
      updateTreeMetadata(this.root);
      return;
    }
    let current = this.root;
    let parent = SENTINEL;
    while (current !== SENTINEL) {
      parent = current;
      current = current.right;
    }
    newNode.parent = parent;
    if (parent === SENTINEL) {
      this.root = newNode;
    } else {
      parent.right = newNode;
    }
    newNode.left = SENTINEL;
    newNode.right = SENTINEL;
    newNode.color = 0;
    let n3 = newNode;
    while (n3 !== SENTINEL) {
      updateTreeMetadata(n3);
      n3 = n3.parent;
    }
    fixInsert({ root: this.root }, newNode);
    this.root = this.root.constructor === TreeNode ? this.root : this.root;
  }
  /**
   * Get the text content from a specific line of a node.
   */
  _getLineFromNode(node, lineNumber) {
    const buffer = this._buffers[node.piece.bufferIndex];
    const piece = node.piece;
    const nodeStartLine = this._getLineNumberForNode(node);
    const lineOffset = lineNumber - nodeStartLine;
    if (lineOffset < 0 || lineOffset > piece.lineFeedCnt) return "";
    const bufferLineIdx = piece.start.line + lineOffset;
    if (bufferLineIdx < 0 || bufferLineIdx >= buffer.lineCount) return "";
    return buffer.getLineContent(bufferLineIdx);
  }
  /**
   * Get the 1-based line number in the document for a node's start.
   */
  _getLineNumberForNode(node, knownOffset) {
    let line = 1;
    let current = node;
    while (current !== null && current !== SENTINEL) {
      if (current.parent !== SENTINEL && current === current.parent.right) {
        line += current.parent.lf_left + current.parent.piece.lineFeedCnt;
      } else if (current.parent !== SENTINEL && current === current.parent.left) ;
      current = current.parent;
    }
    line = this._computeLineNumber(this.root, node);
    return line;
  }
  _computeLineNumber(root, target) {
    let line = 1;
    let current = root;
    while (current !== SENTINEL && current !== target) {
      if (this._isLeftOf(current, target)) {
        line += current.lf_left + current.piece.lineFeedCnt;
        current = current.right;
      } else {
        current = current.left;
      }
    }
    if (current === target) {
      line += current.lf_left;
    }
    return line;
  }
  _isLeftOf(node, target) {
    let current = target;
    while (current !== null && current !== SENTINEL && current !== node) {
      if (current === node.right) return true;
      current = current.parent;
    }
    return false;
  }
  /**
   * Get the offset for a specific line within a node.
   */
  _getOffsetForNodeLine(node, nodeStartLine, lineRemainder) {
    const buffer = this._buffers[node.piece.bufferIndex];
    const piece = node.piece;
    const lineInBuffer = piece.start.line + lineRemainder - 1;
    if (lineInBuffer < 0 || lineInBuffer >= buffer.lineCount) return 0;
    const lineStartInBuffer = buffer.lineStarts[lineInBuffer];
    const pieceStartInBuffer = buffer.lineStarts[piece.start.line];
    const colOffset = lineStartInBuffer - pieceStartInBuffer + piece.start.column;
    return this._getPieceStartOffset(node) + colOffset;
  }
  /**
   * Find which line in the buffer contains the given offset within a piece.
   */
  _findLineInBuffer(buffer, piece, offsetInPiece) {
    const pieceStartInBuffer = buffer.lineStarts[piece.start.line] + piece.start.column;
    const targetBufferOffset = pieceStartInBuffer + offsetInPiece;
    let low = piece.start.line;
    let high = piece.end.line;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      const lineStart = buffer.lineStarts[mid];
      const nextLineStart = mid + 1 < buffer.lineCount ? buffer.lineStarts[mid + 1] : buffer.buffer.length;
      if (targetBufferOffset < lineStart) {
        high = mid - 1;
      } else if (targetBufferOffset >= nextLineStart) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    return piece.start.line;
  }
  /**
   * Get the length of a line in the buffer (0-based line index).
   */
  _getLineLength(buffer, lineIdx) {
    if (lineIdx < 0 || lineIdx >= buffer.lineCount) return 0;
    const start = buffer.lineStarts[lineIdx];
    const end = lineIdx + 1 < buffer.lineCount ? buffer.lineStarts[lineIdx + 1] : buffer.buffer.length;
    return end - start;
  }
  /**
   * Get the length of a line in the document (1-based line number).
   */
  _getLineLengthAtLine(lineNumber) {
    const content = this.getLineContent(lineNumber);
    return content.length;
  }
  /**
   * Count the number of EOLs in a string.
   */
  _countEOLs(text) {
    let count = 0;
    for (let i3 = 0; i3 < text.length; i3++) {
      if (text.charCodeAt(i3) === CharCode.LineFeed) count++;
    }
    return count;
  }
  /**
   * Extract text from the document given an offset and length.
   */
  _getTextFromOffset(offset, length) {
    if (length === 0) return "";
    const parts = [];
    let remaining = length;
    let currentOffset = offset;
    while (remaining > 0) {
      const pos = this.nodeAt(currentOffset);
      if (pos.node === SENTINEL) break;
      const buffer = this._buffers[pos.node.piece.bufferIndex];
      const piece = pos.node.piece;
      const pieceStart = this._getPieceStartOffset(pos.node);
      const offsetInPiece = currentOffset - pieceStart;
      const pieceRemaining = piece.length - offsetInPiece;
      const chunkLength = Math.min(remaining, pieceRemaining);
      const text = this._getPieceText(piece, buffer);
      parts.push(text.substring(offsetInPiece, offsetInPiece + chunkLength));
      remaining -= chunkLength;
      currentOffset += chunkLength;
    }
    return parts.join("");
  }
  /**
   * Recompute line starts after appending to the change buffer.
   */
  _recomputeLineStartsFrom(startOffset, appendedText, oldBuffer) {
    const r2 = [];
    for (let i3 = 0; i3 < oldBuffer.lineStarts.length; i3++) {
      r2.push(oldBuffer.lineStarts[i3]);
    }
    for (let i3 = 0; i3 < appendedText.length; i3++) {
      if (appendedText.charCodeAt(i3) === CharCode.LineFeed) {
        r2.push(startOffset + i3 + 1);
      }
    }
    return createLineStartsFast(appendedText);
  }
  /**
   * Append text to the change buffer and create a new piece.
   */
  _appendToChangeBuffer(text, eolCount) {
    const oldBuffer = this._buffers[0];
    const newBufferStr = oldBuffer.buffer + text;
    const newLineStarts = createLineStartsFast(newBufferStr);
    const newBuffer = new StringBuffer(newBufferStr, newLineStarts);
    const oldLineCount = oldBuffer.lineCount;
    const newLineCount = newBuffer.lineCount;
    const lastLineLen = this._getLineLength(newBuffer, newLineCount - 1);
    const newPiece = new Piece(
      0,
      { line: oldLineCount - 1, column: this._getLineLength(oldBuffer, oldLineCount - 1) },
      { line: newLineCount - 1, column: lastLineLen },
      eolCount,
      text.length
    );
    this._buffers[0] = newBuffer;
    this._insertNode(newPiece, null);
    this._lineCnt += eolCount;
    this._length += text.length;
  }
  /**
   * Rebuild the entire tree from a single string (used after delete operations).
   */
  _rebuildTreeFromBuffer(text) {
    this._searchCache = new SearchCache(1);
    this._lastVisitedLine = null;
    const lineStarts = createLineStartsFast(text);
    const buf = new StringBuffer(text, lineStarts);
    this._buffers = [buf];
    this.root = SENTINEL;
    const piece = new Piece(
      0,
      { line: 0, column: 0 },
      { line: lineStarts.length - 1, column: this._getLineLength(buf, lineStarts.length - 1) },
      lineStarts.length - 1,
      text.length
    );
    this._insertNode(piece, null);
    if (this.root !== SENTINEL) {
      this.root.color = 1;
    }
    this._lineCnt = lineStarts.length;
    this._length = text.length;
  }
  /**
   * Get the document line number for a given character offset.
   */
  _getLineNumberAtOffset(offset) {
    let line = 1;
    let current = this.root;
    let remaining = offset;
    while (current !== SENTINEL) {
      const leftSize = current.size_left;
      if (remaining < leftSize) {
        current = current.left;
      } else {
        remaining -= leftSize;
        line += current.lf_left;
        if (remaining < current.piece.length) {
          const buffer = this._buffers[current.piece.bufferIndex];
          const piece = current.piece;
          const pieceStart = this._getPieceStartOffset(current);
          const offsetInPiece = offset - pieceStart;
          const text = this._getPieceText(piece, buffer);
          let nlCount = 0;
          for (let i3 = 0; i3 < offsetInPiece && i3 < text.length; i3++) {
            if (text.charCodeAt(i3) === CharCode.LineFeed) nlCount++;
          }
          line += nlCount;
          return line;
        }
        remaining -= current.piece.length;
        line += current.piece.lineFeedCnt;
        current = current.right;
      }
    }
    return line;
  }
}
class Emitter {
  constructor() {
    __publicField(this, "_listeners", []);
    __publicField(this, "_disposed", false);
  }
  get event() {
    return (listener) => this._subscribe(listener);
  }
  _subscribe(listener) {
    this._listeners.push(listener);
    return {
      dispose: () => {
        const idx = this._listeners.indexOf(listener);
        if (idx >= 0) this._listeners.splice(idx, 1);
      }
    };
  }
  fire(event) {
    if (this._disposed) return;
    const listeners = this._listeners.slice();
    for (const listener of listeners) {
      listener(event);
    }
  }
  dispose() {
    this._disposed = true;
    this._listeners = [];
  }
}
class TextChange {
  constructor(originalOffset, originalText, modifiedOffset, modifiedText) {
    this.originalOffset = originalOffset;
    this.originalText = originalText;
    this.modifiedOffset = modifiedOffset;
    this.modifiedText = modifiedText;
  }
  get originalLength() {
    return this.originalText.length;
  }
  get modifiedLength() {
    return this.modifiedText.length;
  }
}
class EditStack {
  constructor() {
    __publicField(this, "_undoStack", []);
    __publicField(this, "_redoStack", []);
    /** Current stack pointer — points to the last applied element. */
    __publicField(this, "_currentIndex", -1);
  }
  get canUndo() {
    return this._currentIndex >= 0;
  }
  get canRedo() {
    return this._currentIndex < this._undoStack.length - 1;
  }
  get size() {
    return this._undoStack.length;
  }
  /**
   * Push a new edit stack element (i.e., the user performed an action).
   * Clears any redo history.
   */
  pushElement(element) {
    this._undoStack = this._undoStack.slice(0, this._currentIndex + 1);
    this._undoStack.push(element);
    this._currentIndex++;
    this._redoStack = [];
  }
  /**
   * Pop the top element from the undo stack (for reverting).
   */
  popUndo() {
    if (!this.canUndo) return null;
    const element = this._undoStack[this._currentIndex];
    this._redoStack.push(element);
    this._currentIndex--;
    return element;
  }
  /**
   * Pop the top element from the redo stack (for re-applying).
   */
  popRedo() {
    if (!this.canRedo) return null;
    this._currentIndex++;
    const element = this._undoStack[this._currentIndex];
    this._redoStack.pop();
    return element;
  }
  /**
   * Peek at the top of the undo stack without popping.
   */
  peekUndo() {
    if (!this.canUndo) return null;
    return this._undoStack[this._currentIndex];
  }
  /**
   * Peek at the top of the redo stack without popping.
   */
  peekRedo() {
    if (!this.canRedo) return null;
    return this._undoStack[this._currentIndex + 1];
  }
  /**
   * Clear all undo/redo history.
   */
  clear() {
    this._undoStack = [];
    this._redoStack = [];
    this._currentIndex = -1;
  }
  /**
   * Get the version ID at the top of the undo stack.
   */
  getAlternativeVersionId() {
    if (this._currentIndex >= 0) {
      return this._undoStack[this._currentIndex].afterVersionId;
    }
    return 0;
  }
}
class PieceTreeDecorationProvider {
  constructor() {
    __publicField(this, "_decorations", /* @__PURE__ */ new Map());
    __publicField(this, "_nextId", 1);
  }
  addDecoration(range, options) {
    const id = `decoration_${this._nextId++}`;
    this._decorations.set(id, { id, range, options });
    return id;
  }
  removeDecoration(id) {
    this._decorations.delete(id);
  }
  setDecorations(decorationId, range, options) {
    this._decorations.set(decorationId, { id: decorationId, range, options });
  }
  getDecorationsInRange(range) {
    const result = [];
    for (const decoration of this._decorations.values()) {
      if (this._rangesIntersect(decoration.range, range)) {
        result.push(decoration);
      }
    }
    return result;
  }
  getDecoration(id) {
    return this._decorations.get(id) ?? null;
  }
  removeAllDecorations() {
    this._decorations.clear();
  }
  _rangesIntersect(a2, b2) {
    if (a2.endLineNumber < b2.startLineNumber || a2.endLineNumber === b2.startLineNumber && a2.endColumn <= b2.startColumn)
      return false;
    if (b2.endLineNumber < a2.startLineNumber || b2.endLineNumber === a2.startLineNumber && b2.endColumn <= a2.startColumn)
      return false;
    return true;
  }
}
class PieceTreeTextContentModel {
  constructor(uri, content, options) {
    __publicField(this, "uri");
    __publicField(this, "_pieceTree");
    __publicField(this, "_eol", "\n");
    __publicField(this, "_isDirty", false);
    __publicField(this, "_versionId", 0);
    __publicField(this, "_editStack", new EditStack());
    __publicField(this, "_pendingCursorState", null);
    __publicField(this, "_decorationProvider", new PieceTreeDecorationProvider());
    __publicField(this, "_onDidChangeContent", new Emitter());
    __publicField(this, "_onDidChangeDirty", new Emitter());
    __publicField(this, "_fileReader");
    __publicField(this, "_disposed", false);
    this.uri = uri;
    this._fileReader = options == null ? void 0 : options.fileReader;
    const crlfIndex = content.indexOf("\r\n");
    const lfIndex = content.indexOf("\n");
    if (crlfIndex >= 0 && (lfIndex < 0 || crlfIndex < lfIndex)) {
      this._eol = "\r\n";
    } else {
      this._eol = "\n";
    }
    if (options == null ? void 0 : options.eol) {
      this._eol = options.eol;
    }
    const normalized = content.replace(/\r\n/g, "\n");
    const lineStarts = createLineStartsFast(normalized);
    const buffer = new StringBuffer(normalized, lineStarts);
    this._pieceTree = new PieceTreeBase([buffer], "\n", true);
  }
  // ─── Read-only properties ────────────────────────────────────────────
  get eol() {
    return this._eol;
  }
  get lineCount() {
    return this._pieceTree.getLineCount();
  }
  get length() {
    return this._pieceTree.getLength();
  }
  get isDirty() {
    return this._isDirty;
  }
  get versionId() {
    return this._versionId;
  }
  get alternativeVersionId() {
    return this._editStack.getAlternativeVersionId();
  }
  get decorationProvider() {
    return this._decorationProvider;
  }
  // ─── Events ──────────────────────────────────────────────────────────
  get onDidChangeContent() {
    return this._onDidChangeContent.event;
  }
  get onDidChangeDirty() {
    return this._onDidChangeDirty.event;
  }
  // ─── Reading ──────────────────────────────────────────────────────────
  getLineContent(lineNumber) {
    return this._pieceTree.getLineContent(lineNumber);
  }
  getValueInRange(range) {
    return this._pieceTree.getValueInRange(
      range.startLineNumber,
      range.startColumn,
      range.endLineNumber,
      range.endColumn
    );
  }
  getValue() {
    return this._pieceTree.getValue(this._eol);
  }
  getOffsetAt(position) {
    return this._pieceTree.getOffsetAt(position.lineNumber, position.column);
  }
  getPositionAt(offset) {
    return this._pieceTree.getPositionAt(offset);
  }
  getLineMinColumn(_lineNumber) {
    return 1;
  }
  getLineMaxColumn(lineNumber) {
    const line = this.getLineContent(lineNumber);
    return line.length + 1;
  }
  // ─── Writing ──────────────────────────────────────────────────────────
  /**
   * Set the cursor state before the next edit operation.
   * Consumed by pushEditOperations to record the pre-edit cursor position
   * in the undo stack, so undo can restore it.
   */
  setBeforeEditCursorState(states) {
    if (!states || states.length === 0) {
      this._pendingCursorState = null;
      return;
    }
    this._pendingCursorState = states.map((state) => ({
      selectionStartLineNumber: state.selectionStartLineNumber,
      selectionStartColumn: state.selectionStartColumn,
      positionLineNumber: state.positionLineNumber,
      positionColumn: state.positionColumn
    }));
  }
  pushEditOperations(edits, cursorStateComputer) {
    if (edits.length === 0) return null;
    const beforeCursorState = this._pendingCursorState;
    this._pendingCursorState = null;
    const textChanges = [];
    const beforeVersionId = this._versionId;
    for (const edit of edits) {
      const { range, text } = edit;
      const normalizedText = text.replace(/\r\n/g, "\n");
      const startOffset = this.getOffsetAt({
        lineNumber: range.startLineNumber,
        column: range.startColumn
      });
      const endOffset = range.endLineNumber >= 0 ? this.getOffsetAt({
        lineNumber: range.endLineNumber,
        column: range.endColumn
      }) : startOffset;
      const rangeLength = endOffset - startOffset;
      const oldText = this.getValueInRange(range);
      if (rangeLength > 0) {
        this._pieceTree.delete(startOffset, rangeLength);
      }
      if (normalizedText.length > 0) {
        this._pieceTree.insert(startOffset, normalizedText, true);
      }
      const textChange = new TextChange(startOffset, oldText, startOffset, normalizedText);
      textChanges.push(textChange);
      this._versionId++;
    }
    this._editStack.pushElement({
      changes: textChanges,
      beforeCursorState,
      afterCursorState: null,
      beforeEOL: this._eol,
      afterEOL: this._eol,
      beforeVersionId,
      afterVersionId: this._versionId
    });
    if (!this._isDirty) {
      this._isDirty = true;
      this._onDidChangeDirty.fire(true);
    }
    const changes = edits.map((edit) => ({
      range: {
        startLineNumber: edit.range.startLineNumber,
        startColumn: edit.range.startColumn,
        endLineNumber: edit.range.endLineNumber,
        endColumn: edit.range.endColumn
      },
      rangeLength: edit.text.length > 0 ? this.getOffsetAt({
        lineNumber: edit.range.endLineNumber,
        column: edit.range.endColumn
      }) - this.getOffsetAt({
        lineNumber: edit.range.startLineNumber,
        column: edit.range.startColumn
      }) : 0,
      text: edit.text,
      rangeOffset: this.getOffsetAt({
        lineNumber: edit.range.startLineNumber,
        column: edit.range.startColumn
      })
    }));
    this._onDidChangeContent.fire({
      changes,
      isUndoing: false,
      isRedoing: false,
      versionId: this._versionId
    });
    if (cursorStateComputer) {
      const inverseEdits = edits.map((edit) => ({
        range: {
          startLineNumber: edit.range.startLineNumber,
          startColumn: edit.range.startColumn,
          endLineNumber: edit.range.endLineNumber,
          endColumn: edit.range.endColumn
        },
        text: this.getValueInRange({
          startLineNumber: edit.range.startLineNumber,
          startColumn: edit.range.startColumn,
          endLineNumber: edit.range.endLineNumber,
          endColumn: edit.range.endColumn
        })
      }));
      return cursorStateComputer(inverseEdits);
    }
    return null;
  }
  setValue(newValue) {
    const normalized = newValue.replace(/\r\n/g, "\n");
    const lineStarts = createLineStartsFast(normalized);
    const buffer = new StringBuffer(normalized, lineStarts);
    this._pieceTree = new PieceTreeBase([buffer], "\n", true);
    this._editStack.clear();
    this._versionId++;
    if (!this._isDirty) {
      this._isDirty = true;
      this._onDidChangeDirty.fire(true);
    }
    this._onDidChangeContent.fire({
      changes: [
        {
          range: {
            startLineNumber: 1,
            startColumn: 1,
            endLineNumber: this.lineCount,
            endColumn: 1
          },
          rangeLength: 0,
          text: newValue,
          rangeOffset: 0
        }
      ],
      isUndoing: false,
      isRedoing: false,
      versionId: this._versionId
    });
  }
  markClean() {
    if (this._isDirty) {
      this._isDirty = false;
      this._onDidChangeDirty.fire(false);
    }
  }
  // ─── Undo / Redo ─────────────────────────────────────────────────────
  canUndo() {
    return this._editStack.canUndo;
  }
  canRedo() {
    return this._editStack.canRedo;
  }
  undo() {
    const element = this._editStack.popUndo();
    if (!element) return null;
    for (let i3 = element.changes.length - 1; i3 >= 0; i3--) {
      const change = element.changes[i3];
      if (change.modifiedText.length > 0) {
        this._pieceTree.delete(change.modifiedOffset, change.modifiedText.length);
      }
      if (change.originalText.length > 0) {
        this._pieceTree.insert(change.originalOffset, change.originalText, true);
      }
    }
    this._versionId = element.beforeVersionId;
    this._onDidChangeContent.fire({
      changes: element.changes.map((c2) => {
        const startPos = this.getPositionAt(c2.originalOffset);
        const endPos = this.getPositionAt(c2.originalOffset + c2.originalText.length);
        return {
          range: {
            startLineNumber: startPos.lineNumber,
            startColumn: startPos.column,
            endLineNumber: endPos.lineNumber,
            endColumn: endPos.column
          },
          rangeLength: c2.modifiedText.length,
          text: c2.originalText,
          rangeOffset: c2.originalOffset
        };
      }),
      isUndoing: true,
      isRedoing: false,
      versionId: this._versionId
    });
    return element.beforeCursorState;
  }
  redo() {
    const element = this._editStack.popRedo();
    if (!element) return null;
    for (const change of element.changes) {
      if (change.originalText.length > 0) {
        this._pieceTree.delete(change.originalOffset, change.originalText.length);
      }
      if (change.modifiedText.length > 0) {
        this._pieceTree.insert(change.modifiedOffset, change.modifiedText, true);
      }
    }
    this._versionId = element.afterVersionId;
    this._onDidChangeContent.fire({
      changes: element.changes.map((c2) => {
        const startPos = this.getPositionAt(c2.modifiedOffset);
        const endPos = this.getPositionAt(c2.modifiedOffset + c2.modifiedText.length);
        return {
          range: {
            startLineNumber: startPos.lineNumber,
            startColumn: startPos.column,
            endLineNumber: endPos.lineNumber,
            endColumn: endPos.column
          },
          rangeLength: c2.originalText.length,
          text: c2.modifiedText,
          rangeOffset: c2.modifiedOffset
        };
      }),
      isUndoing: false,
      isRedoing: true,
      versionId: this._versionId
    });
    return element.afterCursorState;
  }
  // ─── Lifecycle ───────────────────────────────────────────────────────
  dispose() {
    if (this._disposed) return;
    this._disposed = true;
    this._onDidChangeContent.dispose();
    this._onDidChangeDirty.dispose();
    this._decorationProvider.removeAllDecorations();
    this._editStack.clear();
  }
}
var __defProp2 = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __decorateClass = (decorators, target, key, kind) => {
  var result = kind > 1 ? void 0 : kind ? __getOwnPropDesc(target, key) : target;
  for (var i3 = decorators.length - 1, decorator; i3 >= 0; i3--)
    if (decorator = decorators[i3])
      result = (kind ? decorator(target, key, result) : decorator(result)) || result;
  if (kind && result) __defProp2(target, key, result);
  return result;
};
const JSON_EDITOR_CHANGE = "json-editor-change";
const JSON_EDITOR_OVERWRITE = "json-editor-overwrite";
function keyNameFromToken(value) {
  if (value.length < 2 || value[0] !== '"' || value[value.length - 1] !== '"') return null;
  const inner = value.slice(1, -1);
  let out = "";
  for (let i3 = 0; i3 < inner.length; i3++) {
    const c2 = inner[i3];
    if (c2 === "\\" && i3 + 1 < inner.length) {
      const n3 = inner[i3 + 1];
      out += n3 === "n" ? "\n" : n3 === "t" ? "	" : n3 === "r" ? "\r" : n3;
      i3++;
    } else {
      out += c2;
    }
  }
  return out;
}
const GUTTER_PAD_PX = 8;
const DEFAULT_DIGIT_PX = 6.6;
const SUGGEST_ITEM_H = 24;
const GUTTER_FOLD_PX = 24;
const TOOLTIP_DELAY_MS = 350;
function gutterWidthFor(rowCount, digitPx) {
  const digits = String(Math.max(1, rowCount)).length;
  return digits * digitPx + GUTTER_PAD_PX * 2;
}
function collectOverrideLeaves(value, def, path, out) {
  if (value !== null && typeof value === "object" && !Array.isArray(value) && def !== null && typeof def === "object" && !Array.isArray(def)) {
    for (const key of Object.keys(value)) {
      collectOverrideLeaves(
        value[key],
        def[key],
        [...path, key],
        out
      );
    }
    return;
  }
  if (JSON.stringify(value) !== JSON.stringify(def)) out.add(pathKey(path));
}
function hasOverrideUnder(overrides, key) {
  if (overrides.has(key)) return true;
  if (key === "") return overrides.size > 0;
  const prefix2 = key + ".";
  for (const q of overrides) {
    if (q.startsWith(prefix2)) return true;
  }
  return false;
}
function markDefaultLines(node, path, faded, overrides, defaults) {
  const key = pathKey(path);
  if (path.length > 0 && !hasOverrideUnder(overrides, key) && getAt(defaults, path) !== void 0) {
    for (let l2 = node.line; l2 <= node.endLine; l2++) faded.add(l2);
    return;
  }
  if (node.type === "object" && node.members) {
    for (const m2 of node.members) {
      markDefaultLines(m2.value, [...path, m2.key], faded, overrides, defaults);
    }
  } else if (node.type === "array" && node.elements) {
    for (let i3 = 0; i3 < node.elements.length; i3++) {
      markDefaultLines(node.elements[i3], [...path, i3], faded, overrides, defaults);
    }
  }
}
const jsonEditorDefaults = { rowHeight: 20, fontSize: 13 };
const liveEditors = /* @__PURE__ */ new Set();
function setJsonEditorDefaults(defaults) {
  Object.assign(jsonEditorDefaults, defaults);
  for (const editor of liveEditors) editor.applySharedDefaults();
}
let JsonEditorElement = class extends i$1 {
  constructor() {
    super(...arguments);
    this.value = void 0;
    this.readonly = false;
    this.rowHeight = void 0;
    this.fontSize = void 0;
    this.schema = null;
    this.resolveResource = null;
    this.defaults = null;
    this.showDefaults = false;
    this.explicitPaths = [];
    this._text = "";
    this._parsedValue = void 0;
    this._committedJson = "";
    this._digitPx = 0;
    this._folds = [];
    this._folded = /* @__PURE__ */ new Set();
    this._hiddenLines = /* @__PURE__ */ new Set();
    this._visibleLines = [];
    this._visibleText = "";
    this._visToFull = [];
    this._fullLineStarts = [];
    this._tokens = [];
    this._selectables = [];
    this._dangerLines = /* @__PURE__ */ new Set();
    this._highlightKind = "delete";
    this._fadedLines = /* @__PURE__ */ new Set();
    this._overrideLeafPaths = /* @__PURE__ */ new Set();
    this._hoverLine = null;
    this._activeLine = null;
    this._braceMatch = null;
    this._gutter = null;
    this._gutterVisText = "";
    this._gutterRowH = 0;
    this._gutterW = -1;
    this._gutterFoldW = -1;
    this._lastSelKey = null;
    this._lastVisText = "";
    this._contentCharW = 0;
    this._ttLine = -1;
    this._ttTokens = [];
    this._ttKeyStarts = /* @__PURE__ */ new Set();
    this._tooltipHoverKey = null;
    this._tooltipPending = null;
    this._tooltipLoadSeq = 0;
    this._tooltipShowTimer = null;
    this._suggest = null;
    this._suggestSuppress = null;
    this._carets = [];
    this._primaryAnchor = 0;
    this._primaryPosition = 0;
    this._caretEls = [];
    this._caretVisible = true;
    this._caretRaf = null;
    this._isFocused = false;
    this._altClicked = false;
    this._dragMoved = false;
    this._dragStartX = 0;
    this._dragStartY = 0;
    this._onSelectionChange = () => {
      this._syncActiveLine();
      this._renderCarets();
    };
    this._onFocus = () => {
      this._isFocused = true;
      this._renderCarets();
      this._syncActiveLine();
      this._updateSuggest();
    };
    this._onBeforeInput = (e2) => {
      if (this.readonly || this._carets.length === 0) return;
      const type = e2.inputType;
      if (type === "insertText") {
        e2.preventDefault();
        this._multiInsert(e2.data ?? "");
      } else if (type === "insertLineBreak" || type === "insertParagraph") {
        e2.preventDefault();
        this._multiNewline();
      } else if (type === "deleteContentBackward" || type === "deleteWordBackward") {
        e2.preventDefault();
        this._multiBackspace();
      } else if (type === "deleteContentForward" || type === "deleteWordForward") {
        e2.preventDefault();
        this._multiDelete();
      } else if (type === "insertFromPaste" || type === "insertFromDrop") {
        e2.preventDefault();
        this._multiInsert(e2.data ?? "");
      }
    };
    this._onBlur = () => {
      this._isFocused = false;
      this._suggestSuppress = null;
      this._hideSuggest();
      this._renderCarets();
      this._syncActiveLine();
      const formatted = this._formatText(this._text);
      if (formatted !== null && formatted !== this._text) {
        this._folded.clear();
        this._text = formatted;
        this._rebuild(true);
      }
    };
    this._onMouseMove = (e2) => {
      if (e2.buttons > 0 && !this._dragMoved) {
        const dx = e2.clientX - this._dragStartX;
        const dy = e2.clientY - this._dragStartY;
        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) this._dragMoved = true;
      }
      if (this._dragMoved && e2.buttons > 0) {
        const ta = this._inputEl();
        if (ta && this._carets.length > 0) {
          this._primaryAnchor = ta.selectionStart;
          this._primaryPosition = ta.selectionEnd;
        }
        this._updateSelectionHighlight();
      }
      const rowH = this._rowH();
      const idx = Math.floor(e2.offsetY / rowH);
      const line = idx >= 0 && idx < this._visibleLines.length ? this._visibleLines[idx].line : null;
      if (line !== this._hoverLine) {
        this._hoverLine = line;
        this.requestUpdate();
      }
      this._updateKeyTooltip(idx, e2.offsetX);
    };
    this._onMousedown = (e2) => {
      this._dragMoved = false;
      this._dragStartX = e2.clientX;
      this._dragStartY = e2.clientY;
      if (e2.altKey && !this.readonly && e2.button === 0) {
        e2.preventDefault();
        this._altClicked = true;
        const pos = this._clickedPos(e2);
        this._toggleCaret(pos);
      }
    };
    this._onMouseLeave = () => {
      if (this._hoverLine !== null || this._dangerLines.size > 0) {
        this._hoverLine = null;
        this._dangerLines = /* @__PURE__ */ new Set();
        this._highlightKind = "delete";
        this.requestUpdate();
      }
      this._resetTooltipState();
    };
    this._onKeyup = (e2) => {
      const ta = e2.target;
      this._updateBraceMatch(ta);
      this._syncActiveLine();
      this._renderCarets();
      this._updateSuggest();
    };
    this._onClick = (e2) => {
      if (this.readonly) return;
      const ta = e2.target;
      if (this._altClicked) {
        this._altClicked = false;
        return;
      }
      if (this._carets.length > 0) this._collapseMulti();
      if (this._dragMoved) {
        this._dragMoved = false;
        this._updateBraceMatch(ta);
        this._syncActiveLine();
        return;
      }
      if (ta.selectionStart !== ta.selectionEnd) {
        this._updateBraceMatch(ta);
        this._syncActiveLine();
        return;
      }
      const pos = ta.selectionStart;
      const r2 = this._selectableAt(pos);
      if (r2) {
        ta.setSelectionRange(r2.start, r2.end);
        this._updateSuggest();
      }
      this._updateBraceMatch(ta);
      this._syncActiveLine();
    };
    this._ensureCaretVisible = () => {
      const ta = this.renderRoot.querySelector("textarea.je-input");
      const vp = this.renderRoot.querySelector(".je-viewport");
      if (!ta || !vp) return;
      const lh = this._rowH();
      const line = ta.value.slice(0, ta.selectionStart).split("\n").length - 1;
      const top = line * lh;
      if (top < vp.scrollTop) vp.scrollTop = top;
      else if (top + lh > vp.scrollTop + vp.clientHeight) vp.scrollTop = top + lh - vp.clientHeight;
    };
  }
  connectedCallback() {
    super.connectedCallback();
    liveEditors.add(this);
    this._digitPx = this._effectiveDigitPx();
    if (this._text === "" && this.value !== void 0) {
      this._applyValue();
    } else {
      this._rebuild(false);
      this._applyRowHeight();
    }
    document.addEventListener("selectionchange", this._onSelectionChange);
    this._startCaretBlink();
  }
  disconnectedCallback() {
    super.disconnectedCallback();
    liveEditors.delete(this);
    document.removeEventListener("selectionchange", this._onSelectionChange);
    this._stopCaretBlink();
    this._caretEls = [];
  }
  /** Recompute and apply the active gutter row from the textarea caret. */
  _syncActiveLine() {
    var _a2;
    const ta = this.renderRoot.querySelector(".je-input");
    if (!ta) return;
    const key = this._isFocused ? this._activeLineFor(ta) : null;
    if (key !== this._activeLine) {
      this._activeLine = key;
      (_a2 = this._gutter) == null ? void 0 : _a2.setActiveRow(key);
    }
  }
  /** The gutter key of the visible line containing the caret. */
  _activeLineFor(ta) {
    const pos = ta.selectionStart ?? 0;
    const lineIdx = ta.value.slice(0, pos).split("\n").length - 1;
    const v2 = this._visibleLines[lineIdx];
    return v2 ? v2.line : null;
  }
  willUpdate(changed) {
    if (changed.has("value") && this._formatValue(this.value) !== this._text) {
      this._applyValue();
    }
    if (changed.has("rowHeight") || changed.has("fontSize")) {
      this._applyRowHeight();
    }
    if (changed.has("showDefaults") || changed.has("defaults") || changed.has("explicitPaths")) {
      this._computeFadedLines();
    }
  }
  /** The parsed value of the current text (last valid parse while transiently
   * invalid). This is what the host should save. */
  get editedValue() {
    return this._parsedValue;
  }
  // ── State / structure ────────────────────────────────────────────────────
  _applyValue() {
    const text = this._formatValue(this.value);
    this._text = text;
    this._folded.clear();
    const res = parseJson(text);
    if (res.ok) {
      this._parsedValue = res.value;
      this._committedJson = JSON.stringify(res.value);
    } else {
      this._parsedValue = this.value;
      this._committedJson = JSON.stringify(this._parsedValue);
    }
    this._rebuild(false);
  }
  /** Re-apply the shared row height / font size (`setJsonEditorDefaults`). */
  applySharedDefaults() {
    this._applyRowHeight();
    this.requestUpdate();
  }
  /** The row height in use (px): this editor's own, else the shared default. */
  _rowH() {
    return Math.max(1, Number(this.rowHeight) || jsonEditorDefaults.rowHeight);
  }
  /** The font size in use (px): this editor's own, else the shared default. */
  _fontPx() {
    return Math.max(1, Number(this.fontSize) || jsonEditorDefaults.fontSize);
  }
  /** Apply the row height and font size (and what depends on them). */
  _applyRowHeight() {
    const lh = this._rowH();
    const fontPx = this._fontPx();
    if (this.style.getPropertyValue("--je-font-size") !== fontPx + "px") {
      this.style.setProperty("--je-font-size", fontPx + "px");
      this._contentCharW = 0;
    }
    this.style.setProperty("--je-row-height", lh + "px");
    this.style.setProperty(
      "--je-gutter-w",
      gutterWidthFor(this._lineCount(), this._digitPx) + "px"
    );
    this.style.setProperty("--je-fold-w", GUTTER_FOLD_PX + "px");
  }
  _formatValue(v2) {
    if (v2 === void 0) return "";
    if (v2 === null) return "null";
    return JSON.stringify(v2, null, 2) ?? String(v2);
  }
  _formatText(text) {
    try {
      const parsed = JSON.parse(text);
      return JSON.stringify(parsed, null, 2) ?? String(parsed);
    } catch {
      return null;
    }
  }
  _lineCount() {
    return this._text.split("\n").length;
  }
  _effectiveDigitPx() {
    if (this._digitPx > 0) return this._digitPx;
    if (typeof document === "undefined") return DEFAULT_DIGIT_PX;
    const s2 = document.createElement("span");
    s2.style.cssText = "position:absolute;visibility:hidden;white-space:pre;font-family:ui-monospace,'Cascadia Code','Fira Code',Menlo,Consolas,monospace;font-size:11px;";
    s2.textContent = "0";
    document.body.appendChild(s2);
    const w = s2.getBoundingClientRect().width;
    s2.remove();
    this._digitPx = w > 0 ? w : DEFAULT_DIGIT_PX;
    return this._digitPx;
  }
  /** Recompute structure (parse → AST / error), fold ranges, and the visible
   * (folded) buffer. Optionally emits `json-editor-change` when a new valid
   * value forms. */
  _rebuild(emitChange) {
    const res = parseJson(this._text);
    let json;
    if (res.ok) {
      this._root = res.root;
      this._parsedValue = res.value;
      this._parseError = void 0;
      json = JSON.stringify(res.value);
    } else {
      this._root = void 0;
      this._parseError = res.error;
    }
    this._folds = computeFoldRanges(this._text);
    const valid = new Set(this._folds.map((f2) => f2.openLine));
    for (const o2 of [...this._folded]) if (!valid.has(o2)) this._folded.delete(o2);
    this._computeVisible();
    this._tokens = tokenizeJsonFull(this._visibleText);
    this._selectables = selectableRanges(this._tokens);
    this._computeFadedLines();
    if (emitChange && json !== void 0 && json !== this._committedJson) {
      this._committedJson = json;
      this.dispatchEvent(
        new CustomEvent(JSON_EDITOR_CHANGE, {
          detail: { value: this._parsedValue },
          bubbles: true,
          composed: true
        })
      );
    }
    this._applyRowHeight();
    this.requestUpdate();
  }
  /** Recompute which lines are part of a default (non-overridden) subtree so
   *  they render faded when `showDefaults` is on. No fade when the mode is off
   *  or no defaults are supplied. */
  _computeFadedLines() {
    this._fadedLines.clear();
    this._overrideLeafPaths.clear();
    if (!this.showDefaults || this.defaults == null || !this._root) return;
    const overrides = /* @__PURE__ */ new Set();
    collectOverrideLeaves(this._parsedValue, this.defaults, [], overrides);
    for (const p2 of this.explicitPaths) overrides.add(p2);
    this._overrideLeafPaths = overrides;
    const faded = /* @__PURE__ */ new Set();
    markDefaultLines(this._root, [], faded, overrides, this.defaults);
    this._fadedLines = faded;
  }
  _computeVisible() {
    const lines = this._text.split("\n");
    const hidden = /* @__PURE__ */ new Set();
    for (const f2 of this._folds) {
      if (!this._folded.has(f2.openLine)) continue;
      for (let i3 = f2.openLine + 1; i3 <= f2.closeLine; i3++) hidden.add(i3);
    }
    this._hiddenLines = hidden;
    const vis = [];
    let visOff = 0;
    for (let i3 = 0; i3 < lines.length; i3++) {
      if (hidden.has(i3)) continue;
      vis.push({ line: i3, text: lines[i3], start: visOff });
      visOff += lines[i3].length + 1;
    }
    this._visibleLines = vis;
    this._visibleText = vis.map((v2) => v2.text).join("\n");
    this._ttLine = -1;
    this._resetTooltipState();
    const starts = [];
    let off = 0;
    for (let i3 = 0; i3 < lines.length; i3++) {
      starts.push(off);
      off += lines[i3].length + (i3 < lines.length - 1 ? 1 : 0);
    }
    this._fullLineStarts = starts;
    const visToFull = new Array(this._visibleText.length + 1);
    let vo = 0;
    for (const v2 of vis) {
      const fl = starts[v2.line];
      for (let k2 = 0; k2 < v2.text.length; k2++) {
        visToFull[vo] = fl + k2;
        vo++;
      }
      visToFull[vo] = fl + v2.text.length;
      vo++;
    }
    this._visToFull = visToFull;
  }
  _fullLineOf(offset) {
    let lo = 0;
    let hi = this._fullLineStarts.length - 1;
    while (lo < hi) {
      const mid = lo + hi + 1 >> 1;
      if (this._fullLineStarts[mid] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return lo;
  }
  _foldForLine(line) {
    return this._folds.find((f2) => f2.openLine === line);
  }
  // ── Rendering ────────────────────────────────────────────────────────────
  render() {
    return b`
      <div class="je-root">
        <div class="je-viewport">
          <div class="je-inner">
            <div class="je-gutter-mount"></div>
            <div class="je-content">
              <div class="je-selection"></div>
              <div class="je-lines">
                ${this._hlBorder()}${this._visibleLines.map((v2) => this._renderRow(v2))}
              </div>
              <div class="je-tooltip" role="tooltip"></div>
              ${this._renderSuggest()}
              <textarea
                class="je-input"
                .value=${l(this._visibleText)}
                ?readonly=${this.readonly}
                spellcheck="false"
                autocomplete="off"
                autocapitalize="off"
                @input=${this._onInput}
                @beforeinput=${this._onBeforeInput}
                @keydown=${this._onKeydown}
                @keyup=${this._onKeyup}
                @select=${() => {
      this._ensureCaretVisible();
      this._updateSelectionHighlight();
      this._syncActiveLine();
      this._renderCarets();
      this._updateSuggest();
    }}
                @mousedown=${(e2) => this._onMousedown(e2)}
                @mousemove=${this._onMouseMove}
                @mouseleave=${this._onMouseLeave}
                @blur=${this._onBlur}
                @focus=${this._onFocus}
                @click=${this._onClick}
              ></textarea>
              <div class="je-caret-layer"></div>
            </div>
          </div>
        </div>
      </div>
    `;
  }
  /** Re-render the rounded selection highlight after the DOM settles. */
  updated(changed) {
    super.updated(changed);
    this._syncGutter();
    this._syncActiveLine();
    this._updateSelectionHighlight();
    this._renderCarets();
    this._positionSuggestTip();
  }
  // ── Gutter (openp41ge-core-editor-gutter) ─────────────────────────────────────
  firstUpdated() {
    var _a2;
    (_a2 = this.renderRoot.querySelector(".je-root")) == null ? void 0 : _a2.addEventListener("mousedown", (e2) => e2.stopPropagation());
    const mount = this.renderRoot.querySelector(".je-gutter-mount");
    if (!mount) return;
    this._gutter = new Gutter({
      events: {
        onRowClick: (row) => this._selectLine(row.key),
        onRowSelectRange: (a2, b2) => this._selectRange(a2.key, b2.key),
        onHoverChange: (key) => {
          if (this._hoverLine !== key) this._hoverLine = key;
        }
      }
    });
    this._gutter.setColumns([
      lineNumberColumn({
        width: () => gutterWidthFor(this._lineCount(), this._digitPx)
      }),
      foldColumn({
        // Square collapsible buttons: the fold column is as wide as the row
        // is tall, so the full-width chevron button is always a square.
        width: () => Math.max(1, Math.round(this._rowH())),
        onToggle: (line) => this._toggleFold(line)
      })
    ]);
    mount.appendChild(this._gutter.root);
    this._syncGutter();
  }
  /** Push the visible rows + hover into the shared gutter host. Rebuilds the
   *  row set only when content/row-height changes (hover moves just repaint
   *  the hovered row). */
  _syncGutter() {
    if (!this._gutter) return;
    const rowH = this._rowH();
    const gutterW = gutterWidthFor(this._lineCount(), this._digitPx);
    const foldW = Math.max(1, Math.round(this._rowH()));
    if (gutterW !== this._gutterW || foldW !== this._gutterFoldW) {
      this._gutterW = gutterW;
      this._gutterFoldW = foldW;
      this._gutter.reflow();
    }
    if (this._gutterVisText !== this._visibleText || this._gutterRowH !== rowH) {
      this._gutterVisText = this._visibleText;
      this._gutterRowH = rowH;
      this._gutter.setRows(
        this._visibleLines.map((v2, i3) => ({ key: v2.line, top: i3 * rowH, height: rowH })),
        (key) => this._gutterData(key)
      );
      this._gutter.refresh();
    }
  }
  /** Per-row gutter data shared by the built-in columns. */
  _gutterData(key) {
    return {
      error: !!this._parseError && this._parseError.line === key,
      hasChevron: this._foldForLine(key) !== void 0,
      folded: this._folded.has(key)
    };
  }
  /** Select the whole visible line in the editor (click on a line number). */
  _selectLine(fullLine) {
    const ta = this.renderRoot.querySelector(".je-input");
    const v2 = this._visibleLines.find((x2) => x2.line === fullLine);
    if (!ta || !v2) return;
    ta.focus();
    this._collapseMulti();
    ta.setSelectionRange(v2.start, v2.start + v2.text.length);
    this._updateBraceMatch(ta);
    this._updateSelectionHighlight();
    this._syncActiveLine();
  }
  /** Select the range of visible lines [a, b] (drag across line numbers). */
  _selectRange(aLine, bLine) {
    const ta = this.renderRoot.querySelector(".je-input");
    const a2 = this._visibleLines.find((x2) => x2.line === aLine);
    const b2 = this._visibleLines.find((x2) => x2.line === bLine);
    if (!ta || !a2 || !b2) return;
    ta.focus();
    const start = Math.min(a2.start, b2.start);
    const end = Math.max(a2.start + a2.text.length, b2.start + b2.text.length);
    this._collapseMulti();
    ta.setSelectionRange(start, end);
    this._updateBraceMatch(ta);
    this._updateSelectionHighlight();
    this._syncActiveLine();
  }
  /** Build the Monaco-style rounded selection highlight overlay.
   *  Renders EVERY caret's range (primary + extras) as its own rounded set. */
  _updateSelectionHighlight() {
    const ta = this._inputEl();
    const overlay = this.renderRoot.querySelector(".je-selection");
    if (!ta || !overlay) return;
    const ranges = this._allCarets().map((c2) => [c2.s, c2.e]);
    const merged = [];
    for (const r2 of ranges.sort((a2, b2) => a2[0] - b2[0])) {
      const last = merged[merged.length - 1];
      if (last && r2[0] <= last[1]) {
        last[1] = Math.max(last[1], r2[1]);
      } else {
        merged.push([r2[0], r2[1]]);
      }
    }
    const key = merged.map((r2) => `${r2[0]}:${r2[1]}`).join("|");
    if (this._lastSelKey === key && this._lastVisText === this._visibleText) return;
    this._lastSelKey = key;
    this._lastVisText = this._visibleText;
    while (overlay.firstChild) overlay.removeChild(overlay.firstChild);
    const rows = this.renderRoot.querySelectorAll(".je-lines .je-row");
    const rowH = this._rowH();
    for (const [s2, e2] of merged) {
      if (s2 === e2) continue;
      const segs = [];
      this._visibleLines.forEach((v2, i3) => {
        const rowEl = rows[i3];
        if (!rowEl) return;
        const lineStart = v2.start;
        const lineEnd = v2.start + v2.text.length;
        const localStart = Math.max(s2, lineStart) - lineStart;
        const localEnd = Math.min(e2, lineEnd) - lineStart;
        if (localEnd <= localStart || localStart >= v2.text.length) return;
        const lineEl = rowEl.querySelector(".je-line");
        if (!lineEl) return;
        const nodes = this._lineTextNodes(lineEl);
        const left = this._boundaryX(lineEl, nodes, Math.max(0, localStart));
        const right = this._boundaryX(lineEl, nodes, Math.min(v2.text.length, localEnd));
        segs.push({ rowIndex: i3, left, right });
      });
      this._renderSegs(overlay, segs, rowH);
    }
  }
  /** Render one selection's line segments as rounded, intern-joined pieces. */
  _renderSegs(overlay, segs, rowH) {
    if (segs.length === 0) return;
    const W = 3;
    for (let i3 = 0; i3 < segs.length; i3++) {
      const seg = segs[i3];
      const prev = i3 > 0 ? segs[i3 - 1] : null;
      const next = i3 + 1 < segs.length ? segs[i3 + 1] : null;
      const lineNum = this._visibleLines[seg.rowIndex].line;
      const prevAdj = prev && this._visibleLines[prev.rowIndex].line === lineNum - 1;
      const nextAdj = next && this._visibleLines[next.rowIndex].line === lineNum + 1;
      const tl = prevAdj ? this._cornerLeft(seg.left, prev.left, prev.right) : "ex";
      const bl = nextAdj ? this._cornerLeft(seg.left, next.left, next.right) : "ex";
      const tr = prevAdj ? this._cornerRight(seg.right, prev.right) : "ex";
      const br = nextAdj ? this._cornerRight(seg.right, next.right) : "ex";
      const top = seg.rowIndex * rowH;
      const segEl = document.createElement("div");
      let cls = "je-segment";
      if (tl === "ex") cls += " top-left-radius";
      if (tr === "ex") cls += " top-right-radius";
      if (bl === "ex") cls += " bottom-left-radius";
      if (br === "ex") cls += " bottom-right-radius";
      segEl.className = cls;
      segEl.style.left = `${seg.left}px`;
      segEl.style.top = `${top}px`;
      segEl.style.width = `${Math.max(0, seg.right - seg.left)}px`;
      segEl.style.height = `${rowH}px`;
      overlay.appendChild(segEl);
      if (tl === "in") this._renderIntern(overlay, seg.left, top, "left", "top", rowH, W);
      if (bl === "in") this._renderIntern(overlay, seg.left, top, "left", "bottom", rowH, W);
      if (tr === "in") this._renderIntern(overlay, seg.right, top, "right", "top", rowH, W);
      if (br === "in") this._renderIntern(overlay, seg.right, top, "right", "bottom", rowH, W);
    }
  }
  /** FLAT / INTERN / EXTERN for a left corner, vs the adjacent line. */
  _cornerLeft(x2, adjLeft, adjRight) {
    if (Math.abs(x2 - adjLeft) < 1) return "flat";
    if (adjLeft < x2 && x2 < adjRight) return "in";
    return "ex";
  }
  /** FLAT / INTERN / EXTERN for a right corner, vs the adjacent line. */
  _cornerRight(x2, adjRight) {
    if (Math.abs(x2 - adjRight) < 1) return "flat";
    if (x2 < adjRight) return "in";
    return "ex";
  }
  /** Render an INTERN corner: a highlight square with a bg-colored notch. */
  _renderIntern(overlay, edgeX, top, side, edge, rowH, w) {
    const x2 = side === "left" ? edgeX - w : edgeX;
    const y3 = edge === "top" ? top : top + rowH - w;
    const piece = document.createElement("div");
    piece.className = "je-corner-piece";
    piece.style.left = `${x2}px`;
    piece.style.top = `${y3}px`;
    piece.style.width = `${w}px`;
    piece.style.height = `${w}px`;
    overlay.appendChild(piece);
    const notch = document.createElement("div");
    const cornerClass = side === "left" ? edge === "top" ? "top-right-radius" : "bottom-right-radius" : edge === "top" ? "top-left-radius" : "bottom-left-radius";
    notch.className = `je-notch ${cornerClass}`;
    notch.style.left = `${x2}px`;
    notch.style.top = `${y3}px`;
    notch.style.width = `${w}px`;
    notch.style.height = `${w}px`;
    overlay.appendChild(notch);
  }
  _lineTextNodes(lineEl) {
    const walker = document.createTreeWalker(lineEl, NodeFilter.SHOW_TEXT, {
      acceptNode: (n22) => {
        const p2 = n22.parentElement;
        if (p2 && p2.closest(".je-fold-meta")) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    const nodes = [];
    let n3;
    while (n3 = walker.nextNode()) nodes.push(n3);
    return nodes;
  }
  _rangePosAt(nodes, offset) {
    for (const n3 of nodes) {
      if (offset <= n3.data.length) return { node: n3, off: offset };
      offset -= n3.data.length;
    }
    return null;
  }
  /** X of the char boundary at `charIdx`, relative to the line's left edge.
   *  Uses exact glyph measurement (Range rects) when available; falls back
   *  to a constant monospace advance width where DOM layout is unavailable
   *  (e.g. jsdom, headless). */
  _boundaryX(lineEl, nodes, charIdx) {
    const lineRect = lineEl.getBoundingClientRect();
    const pos = this._rangePosAt(nodes, charIdx);
    if (!pos) return 10 + charIdx * this._measureCharW();
    try {
      const range = document.createRange();
      range.setStart(pos.node, pos.off);
      range.setEnd(pos.node, pos.off);
      const r2 = range.getBoundingClientRect();
      if (r2 && typeof r2.left === "number" && Number.isFinite(r2.left)) {
        return r2.left - lineRect.left;
      }
    } catch {
    }
    return 10 + charIdx * this._measureCharW();
  }
  /** Advance width of a single monospace character, measured lazily. */
  _measureCharW() {
    if (this._contentCharW > 0) return this._contentCharW;
    if (typeof document === "undefined" || typeof document.createElement !== "function") {
      this._contentCharW = 7;
      return this._contentCharW;
    }
    const s2 = document.createElement("span");
    s2.style.cssText = `position:absolute;visibility:hidden;white-space:pre;font-family:ui-monospace,'Cascadia Code','Fira Code',Menlo,Consolas,monospace;font-size:${this._fontPx()}px;`;
    s2.textContent = "0".repeat(100);
    document.body.appendChild(s2);
    const w = s2.getBoundingClientRect().width / 100;
    s2.remove();
    this._contentCharW = w > 0 ? w : 7;
    return this._contentCharW;
  }
  _renderRow(v2) {
    const fold = this._foldForLine(v2.line);
    const isFolded = this._folded.has(v2.line);
    const danger = this._dangerLines.has(v2.line);
    const hlClass = danger ? this._highlightKind === "overwrite" ? " je-row--overwrite" : " je-row--danger" : "";
    const closeRow = /^\s*[}\]]\s*,?\s*$/.test(v2.text);
    const faded = this._fadedLines.has(v2.line);
    const isRootLine = this._root != null && v2.line === this._root.line;
    const showDel = !closeRow && !faded && !isRootLine && this._hoverLine === v2.line;
    const showOverwrite = !closeRow && faded && !isRootLine && this._hoverLine === v2.line;
    const tokens = tokenizeJsonFull(v2.text);
    const { keyStarts, valueStarts } = this._classifyTokens(tokens);
    const meta = isFolded ? b`<span class="je-fold-meta">${this._foldMeta(fold)}</span>` : "";
    const openIdx = isFolded ? tokens.findIndex((t2) => t2.kind === "punct" && (t2.value === "{" || t2.value === "[")) : -1;
    const content = tokens.map((t2, i3) => {
      if (isFolded && openIdx >= 0 && i3 >= openIdx) return "";
      const abs = v2.start + t2.start;
      const brace = !isFolded && this._braceMatch !== null && (this._braceMatch[0] === abs || this._braceMatch[1] === abs);
      return this._renderToken(t2, keyStarts, valueStarts, brace);
    });
    const actions = closeRow || isRootLine ? "" : faded ? b`<button
              class="je-ow ${showOverwrite ? "je-ow--show" : ""}"
              title="Overwrite this default value"
              @click=${() => this._overwriteAtLine(v2.line)}
              @mouseenter=${() => {
      this._hoverLine = v2.line;
      this._setRowHighlight(v2.line, "overwrite");
    }}
              @mouseleave=${() => this._clearDanger()}
            >
              <svg
                width="11"
                height="11"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
              </svg>
            </button>` : b`<button
              class="je-del ${showDel ? "je-del--show" : ""}"
              title="Delete"
              @click=${() => this._deleteAtLine(v2.line)}
              @mouseenter=${() => {
      this._hoverLine = v2.line;
      this._setRowHighlight(v2.line, "delete");
    }}
              @mouseleave=${() => this._clearDanger()}
            >
              ×
            </button>`;
    return b`<div
      class="je-row ${hlClass}${faded ? " je-row--faded" : ""}"
      data-line="${v2.line}"
    >
      <div class="je-line">${content}${meta}</div>
      <div class="je-actions">${actions}</div>
    </div>`;
  }
  /** Promote the default value at `fullLine` to an explicit override: emit a
   *  `json-editor-overwrite` event carrying the entry's path and value so the
   *  host can pin it into the user config. */
  _overwriteAtLine(fullLine) {
    if (this.readonly || !this._root || this._parsedValue === void 0) return;
    const m2 = findEntryAtLine(this._root, fullLine);
    if (!m2) return;
    const path = this._pathToNode(this._root, m2.node);
    if (path === null) return;
    this.dispatchEvent(
      new CustomEvent(JSON_EDITOR_OVERWRITE, {
        detail: { path, value: getAt(this._parsedValue, path) },
        bubbles: true,
        composed: true
      })
    );
  }
  /** Per-line token classification: which tokens are object keys / scalar
   * values (for click-to-select and affordance classes). */
  _classifyTokens(tokens) {
    const keyStarts = /* @__PURE__ */ new Set();
    const valueStarts = /* @__PURE__ */ new Set();
    const nonWs = tokens.filter((t2) => t2.kind !== "ws");
    for (let i3 = 0; i3 < nonWs.length; i3++) {
      const t2 = nonWs[i3];
      if (t2.kind === "string") {
        const nxt = nonWs[i3 + 1];
        (nxt && nxt.kind === "punct" && nxt.value === ":" ? keyStarts : valueStarts).add(t2.start);
      } else if (t2.kind === "number" || t2.kind === "keyword") {
        valueStarts.add(t2.start);
      }
    }
    return { keyStarts, valueStarts };
  }
  _renderToken(t2, keyStarts, _valueStarts, braceMatch = false) {
    if (t2.kind === "ws") return t2.value;
    let cls = "s-pun";
    if (keyStarts.has(t2.start)) cls = "s-var";
    else if (t2.kind === "string") cls = "s-str";
    else if (t2.kind === "number") cls = "s-num";
    else if (t2.kind === "keyword") cls = "s-kw";
    if (braceMatch) cls += " je-brace--match";
    return b`<span class="${cls}">${t2.value}</span>`;
  }
  /** Map a mouse x-offset (relative to the textarea) to a column index. */
  _offsetXToCol(offsetX) {
    const cw = this._measureCharW() > 0 ? this._measureCharW() : 8;
    return Math.max(0, Math.floor((offsetX - 10) / cw));
  }
  /** Show/hide the schema tooltip based on which key the mouse is over.
   *  Driven from the textarea's mousemove (the content spans sit beneath the
   *  overlay and never receive pointer events), so the hovered line's key is
   *  resolved from its column and the parsed tree's path. The tooltip is
   *  anchored to the key's own position (its column/row), not the cursor, and
   *  only appears after the cursor has rested on the key for a short delay.
   */
  _updateKeyTooltip(idx, offsetX) {
    var _a2;
    const tip = this.renderRoot.querySelector(".je-tooltip");
    if (!tip) {
      this._resetTooltipState();
      return;
    }
    if (!this.schema) {
      this._resetTooltipState();
      return;
    }
    const v2 = this._visibleLines[idx];
    if (!v2) {
      this._resetTooltipState();
      return;
    }
    if (v2.line !== this._ttLine) {
      this._ttLine = v2.line;
      this._ttTokens = tokenizeJsonFull(v2.text);
      this._ttKeyStarts = this._classifyTokens(this._ttTokens).keyStarts;
    }
    const tokens = this._ttTokens;
    const keyStarts = this._ttKeyStarts;
    const col = this._offsetXToCol(offsetX);
    const keyTok = tokens.find(
      (t2) => keyStarts.has(t2.start) && col >= t2.start && col < t2.start + t2.value.length
    );
    let text = null;
    let hint = null;
    if (keyTok) {
      let path = null;
      if (this._root) {
        path = pathForLine(this._root, v2.line);
      } else {
        const lineFullStart = this._fullLineStarts[v2.line] ?? 0;
        const owner = ownerPathAt(this._text, lineFullStart);
        const keyName = keyNameFromToken(keyTok.value);
        if (owner && keyName !== null) path = [...owner, keyName];
      }
      if (path) {
        const schema = schemaAtPath(this.schema, path);
        text = schemaDescriptionForPath(this.schema, path);
        hint = schemaItemHint(schema);
      }
    }
    const keyId = keyTok && text ? `${v2.line}:${keyTok.start}` : null;
    this._tooltipHoverKey = keyId;
    if (keyId && keyTok && text) {
      if (((_a2 = this._tooltipPending) == null ? void 0 : _a2.keyId) !== keyId) {
        this._hideKeyTooltip();
        this._clearTooltipTimer();
        this._tooltipPending = {
          keyId,
          line: v2.line,
          start: keyTok.start,
          keyLen: keyTok.value.length,
          text,
          hint
        };
        this._tooltipShowTimer = window.setTimeout(() => this._tooltipFire(), TOOLTIP_DELAY_MS);
      }
    } else {
      this._resetTooltipState();
    }
  }
  /** Clear the pending timer, hover key and any visible tooltip. */
  _resetTooltipState() {
    this._clearTooltipTimer();
    this._tooltipPending = null;
    this._tooltipHoverKey = null;
    this._hideKeyTooltip();
  }
  /** Delay elapsed: show the pending key's tooltip if the cursor is still on it.
   *  When the description is a Markdown file reference, the resource is loaded
   *  first (async) and re-checked against the hover state so a stale load can't
   *  paint a tooltip the cursor has since left. */
  async _tooltipFire() {
    this._tooltipShowTimer = null;
    const p2 = this._tooltipPending;
    const seq = ++this._tooltipLoadSeq;
    if (!p2 || this._tooltipHoverKey !== p2.keyId) {
      this._hideKeyTooltip();
      return;
    }
    const v2 = this._visibleLines.find((x2) => x2.line === p2.line);
    const tip = this.renderRoot.querySelector(".je-tooltip");
    if (!v2 || !tip) {
      this._hideKeyTooltip();
      return;
    }
    const idx = this._visibleLines.indexOf(v2);
    let body;
    if (isMarkdownFileRef(p2.text) && this.resolveResource) {
      tip.textContent = "…";
      let content2 = null;
      try {
        content2 = await this.resolveResource(p2.text);
      } catch {
        content2 = null;
      }
      if (seq !== this._tooltipLoadSeq || this._tooltipHoverKey !== p2.keyId) {
        this._hideKeyTooltip();
        return;
      }
      body = content2 ? renderMarkdown(content2) : `<p>${p2.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</p>`;
    } else {
      body = renderMarkdown(p2.text);
    }
    if (p2.hint) {
      body += `<div class="je-tooltip-hint">${p2.hint.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</div>`;
    }
    if (seq !== this._tooltipLoadSeq || this._tooltipHoverKey !== p2.keyId) {
      this._hideKeyTooltip();
      return;
    }
    tip.innerHTML = body;
    tip.style.display = "block";
    const tipW = tip.offsetWidth;
    const rowH = this._rowH();
    const cw = this._measureCharW() > 0 ? this._measureCharW() : 8;
    const keyW = p2.keyLen * cw;
    let left = 10 + p2.start * cw + (keyW - tipW) / 2;
    const viewport = this.renderRoot.querySelector(".je-viewport");
    const content = this.renderRoot.querySelector(".je-content");
    if (viewport && content) {
      const vpRight = viewport.getBoundingClientRect().right - content.getBoundingClientRect().left;
      const maxLeft = vpRight - tipW - 4;
      left = Math.min(left, Math.max(0, maxLeft));
    }
    tip.style.left = `${Math.max(0, left)}px`;
    tip.style.top = `${(idx + 1) * rowH + 2}px`;
  }
  _clearTooltipTimer() {
    if (this._tooltipShowTimer !== null) {
      window.clearTimeout(this._tooltipShowTimer);
      this._tooltipShowTimer = null;
    }
  }
  _hideKeyTooltip() {
    const tip = this.renderRoot.querySelector(".je-tooltip");
    if (tip) tip.style.display = "none";
  }
  // ── Key auto-complete (schema suggestions) ──────────────────────────────
  /** Render the suggestions list (below the caret) and the thin side tooltip
   *  for the highlighted row. Nothing is shown when there is no active list. */
  _renderSuggest() {
    var _a2;
    const s2 = this._suggest;
    if (!s2) return A;
    const tipText = (((_a2 = s2.items[s2.selected]) == null ? void 0 : _a2.description) ?? "").replace(/^\s+/, "") || null;
    const items = s2.items.map((it, i3) => {
      const sel = i3 === s2.selected ? " je-suggest-item--sel" : "";
      const mousedown = (e2) => {
        e2.preventDefault();
        this._acceptSuggest(i3);
      };
      const enter = () => this._selectSuggest(i3);
      return b`<div class="je-suggest-item${sel}" role="option" data-key=${it.key} @mousedown=${mousedown} @mouseenter=${enter}>${it.label ?? it.key}</div>`;
    });
    const tip = tipText ? b`<div class="je-suggest-tip" role="tooltip" style="left:${s2.x + 188}px; top:${s2.tipTop}px">${tipText}</div>` : A;
    return b`
      <div class="je-suggest" role="listbox" style="left:${s2.x}px; top:${s2.y}px">${items}</div>
      ${tip}
    `;
  }
  /** Recompute whether suggestions should show for the current caret and where
   *  the list should sit. Called after every edit and caret move. */
  _updateSuggest() {
    if (this.readonly || this._carets.length > 0) {
      this._suggest = null;
      return;
    }
    const ta = this._inputEl();
    if (!ta) {
      this._suggest = null;
      return;
    }
    const selStart = ta.selectionStart;
    const selEnd = ta.selectionEnd;
    const selectedToken = selStart !== selEnd;
    if (this._suggestSuppress !== null && selStart === this._suggestSuppress) return;
    this._suggestSuppress = null;
    const fullPos = this._visToFull[selStart];
    if (fullPos === void 0 || fullPos === null) {
      this._suggest = null;
      return;
    }
    let items = null;
    let kind = "key";
    const valCtx = valueSuggestContextAt(this.schema, this._text, fullPos, selectedToken);
    if (valCtx) {
      items = valCtx.values.map((val) => ({
        key: val,
        description: valCtx.description,
        type: "string"
      }));
      kind = "value";
    } else if (this.schema) {
      const ctx = suggestContextAt(this._text, fullPos);
      if (ctx) {
        items = collectKeySuggestions(this.schema, ctx.ownerPath, this._parsedValue, ctx.prefix);
        kind = "key";
      }
    }
    if (!items || items.length === 0) {
      this._suggest = null;
      return;
    }
    const rowIdx = this._visibleLines.findIndex(
      (v22) => selStart >= v22.start && selStart <= v22.start + v22.text.length
    );
    if (rowIdx < 0) {
      this._suggest = null;
      return;
    }
    const v2 = this._visibleLines[rowIdx];
    const col = Math.min(selStart - v2.start, v2.text.length);
    const rowH = this._rowH();
    const cw = this._measureCharW() > 0 ? this._measureCharW() : 8;
    const x2 = 10 + col * cw;
    const y3 = (rowIdx + 1) * rowH + 2;
    const prev = this._suggest;
    const sameItems = prev !== null && prev.kind === kind && prev.items.length === items.length && prev.items.every((p2, i3) => p2.key === items[i3].key);
    const selected = sameItems ? Math.min(prev.selected, items.length - 1) : 0;
    this._suggest = {
      x: x2,
      y: y3,
      tipTop: y3 + selected * SUGGEST_ITEM_H,
      items,
      selected,
      kind
    };
  }
  /** Move the highlighted suggestion (clamped). */
  _moveSuggestSelection(delta) {
    const s2 = this._suggest;
    if (!s2) return;
    const selected = Math.min(s2.items.length - 1, Math.max(0, s2.selected + delta));
    if (selected === s2.selected) return;
    this._suggest = { ...s2, selected, tipTop: s2.y + selected * SUGGEST_ITEM_H };
  }
  /** Highlight a suggestion on hover (also swaps the side tooltip). */
  _selectSuggest(i3) {
    const s2 = this._suggest;
    if (!s2 || i3 === s2.selected) return;
    this._suggest = { ...s2, selected: i3, tipTop: s2.y + i3 * SUGGEST_ITEM_H };
  }
  /** Apply the highlighted (or given) suggestion: replace the quoted token
   *  with the key and park the caret after the closing quote. */
  _acceptSuggest(index) {
    const s2 = this._suggest;
    if (!s2) return;
    const item = s2.items[index ?? s2.selected];
    if (!item) return;
    const ta = this._inputEl();
    if (!ta) return;
    if (s2.kind === "value") {
      const selIn = ta.selectionStart;
      const fullPos2 = this._visToFull[selIn];
      if (fullPos2 === void 0 || fullPos2 === null) return;
      const str2 = stringAt(this._text, fullPos2);
      if (!str2) return;
      const line2 = this._fullLineOf(fullPos2);
      const lineFullStart2 = this._fullLineStarts[line2];
      const v22 = this._visibleLines.find((x2) => x2.line === line2);
      if (!v22) return;
      const visOpen2 = v22.start + (str2.open - lineFullStart2);
      const visEnd2 = visOpen2 + (str2.close - str2.open + 1);
      const ins2 = JSON.stringify(item.key);
      this._replaceRange(ta, visOpen2, visEnd2, ins2);
      const caretOffset2 = visOpen2 + ins2.length;
      ta.setSelectionRange(caretOffset2, caretOffset2);
      this._suggest = null;
      this._suggestSuppress = caretOffset2;
      this._afterEdit(ta);
      return;
    }
    const pos = ta.selectionStart;
    const fullPos = this._visToFull[pos];
    if (fullPos === void 0 || fullPos === null) return;
    const str = stringAt(this._text, fullPos);
    if (!str) return;
    const line = this._fullLineOf(fullPos);
    const lineFullStart = this._fullLineStarts[line];
    const v2 = this._visibleLines.find((x2) => x2.line === line);
    if (!v2) return;
    const visOpen = v2.start + (str.open - lineFullStart);
    const visEnd = visOpen + (str.close - str.open + 1);
    const lit = defaultLiteralForType(item.type);
    const ins = `"${item.key}": ${lit.value}`;
    const caretOffset = item.key === "" ? visOpen + 1 : lit.inside ? visOpen + ins.indexOf(lit.value) + 1 : visOpen + ins.length;
    this._replaceRange(ta, visOpen, visEnd, ins);
    ta.setSelectionRange(caretOffset, caretOffset);
    this._suggest = null;
    this._suggestSuppress = caretOffset;
    this._afterEdit(ta);
  }
  /** Dismiss the suggestions list and remember the caret position so it won't
   *  instantly re-open (the caret is still on an empty quoted key). */
  _dismissSuggest() {
    const ta = this._inputEl();
    this._suggest = null;
    this._suggestSuppress = ta ? ta.selectionStart : null;
  }
  /** Dismiss the suggestions list. */
  _hideSuggest() {
    if (this._suggest) this._suggest = null;
  }
  /** Slide the thin side tooltip flush against the list's right edge (the list
   *  width isn't known at render time, so measure it after the DOM settles). */
  _positionSuggestTip() {
    if (!this._suggest) return;
    const list = this.renderRoot.querySelector(".je-suggest");
    const tip = this.renderRoot.querySelector(".je-suggest-tip");
    if (!list || !tip) return;
    tip.style.left = `${list.offsetLeft + list.offsetWidth + 8}px`;
  }
  _foldMeta(fold) {
    if (!fold || !this._root) return "";
    const m2 = findEntryAtLine(this._root, fold.openLine);
    let node = m2 == null ? void 0 : m2.node;
    if (!node && fold.openLine === this._root.line) node = this._root;
    if (!node || node.type !== "object" && node.type !== "array") return "";
    const summary = summarize(node.value);
    return node.type === "object" ? `{ ${summary} }` : `[ ${summary} ]`;
  }
  // ── Editing ──────────────────────────────────────────────────────────────
  _onInput(e2) {
    this._afterEdit(e2.target);
  }
  /** Reconcile a visible-text edit back into the full text, then rebuild. */
  _afterEdit(ta) {
    if (this.readonly) return;
    const newVis = ta.value;
    if (newVis !== this._visibleText) this._applyVisible(newVis);
    this._ensureCaretVisible();
    this._updateBraceMatch(ta);
    this._syncActiveLine();
    this._renderCarets();
    this._updateSuggest();
  }
  _applyVisible(newVis) {
    const oldVis = this._visibleText;
    const p2 = this._commonPrefix(oldVis, newVis);
    const maxS = Math.min(oldVis.length, newVis.length) - p2;
    let s2 = 0;
    while (s2 < maxS && oldVis[oldVis.length - 1 - s2] === newVis[newVis.length - 1 - s2]) s2++;
    const vStart = p2;
    const vEnd = oldVis.length - s2;
    const inserted = newVis.slice(p2, newVis.length - s2);
    const fullStart = this._visToFull[Math.min(vStart, oldVis.length)];
    const fullEnd = this._visToFull[Math.min(vEnd, oldVis.length)];
    if (this._editCrossesFolds(fullStart, fullEnd)) {
      this._folded.clear();
      this._computeVisible();
      this._tokens = tokenizeJsonFull(this._visibleText);
      this._selectables = selectableRanges(this._tokens);
      this._applyRowHeight();
      this.requestUpdate();
      return;
    }
    this._text = this._text.slice(0, fullStart) + inserted + this._text.slice(fullEnd);
    this._rebuild(true);
  }
  _commonPrefix(a2, b2) {
    const n3 = Math.min(a2.length, b2.length);
    let i3 = 0;
    while (i3 < n3 && a2[i3] === b2[i3]) i3++;
    return i3;
  }
  /** True when the full-text region being edited spans any hidden (folded)
   *  line — an edit the user can only have made by crossing a fold. */
  _editCrossesFolds(fullStart, fullEnd) {
    if (this._hiddenLines.size === 0) return false;
    const sLine = this._fullLineOf(fullStart);
    const eLine = this._fullLineOf(fullEnd);
    for (const l2 of this._hiddenLines) {
      if (l2 > sLine && l2 < eLine) return true;
    }
    return false;
  }
  /** Pretty-print/rebuild the parsed value as 2-space text. */
  _toggleFold(openLine) {
    if (this._folded.has(openLine)) this._folded.delete(openLine);
    else this._folded.add(openLine);
    this._computeVisible();
    this._tokens = tokenizeJsonFull(this._visibleText);
    this._selectables = selectableRanges(this._tokens);
    this._applyRowHeight();
    this.requestUpdate();
  }
  _deleteAtLine(fullLine) {
    if (this.readonly || !this._root || this._parsedValue === void 0) return;
    const m2 = findEntryAtLine(this._root, fullLine);
    if (!m2) return;
    const path = this._pathToNode(this._root, m2.parent);
    if (path === null) return;
    const next = cloneDeep(this._parsedValue);
    const container = path.length === 0 ? next : getAt(next, path);
    if (container == null || typeof container !== "object") return;
    if (m2.member && typeof m2.member.key === "string" && !Array.isArray(container)) {
      delete container[m2.member.key];
    } else if (m2.index !== void 0 && Array.isArray(container)) {
      container.splice(m2.index, 1);
    }
    const text = JSON.stringify(next, null, 2) ?? String(next);
    this._folded.clear();
    this._text = text;
    this._rebuild(true);
  }
  /** Path (object keys / array indices) from the root node down to `target`, or
   * null if `target` isn't reachable from `root`. Used to delete a member at
   * its real nesting depth. */
  _pathToNode(root, target) {
    if (root === target) return [];
    if (root.type === "object" && root.members) {
      for (let i3 = 0; i3 < root.members.length; i3++) {
        const p2 = this._pathToNode(root.members[i3].value, target);
        if (p2) return [root.members[i3].key, ...p2];
      }
    } else if (root.type === "array" && root.elements) {
      for (let i3 = 0; i3 < root.elements.length; i3++) {
        const p2 = this._pathToNode(root.elements[i3], target);
        if (p2) return [i3, ...p2];
      }
    }
    return null;
  }
  _setRowHighlight(fullLine, kind) {
    if (!this._root) return;
    const m2 = findEntryAtLine(this._root, fullLine);
    if (!m2) return;
    const set = /* @__PURE__ */ new Set();
    for (let l2 = m2.line; l2 <= m2.node.endLine; l2++) set.add(l2);
    this._dangerLines = set;
    this._highlightKind = kind;
    this.requestUpdate();
  }
  /** The visible block of highlighted lines and the accent color for the
   *  delete / overwrite border. Returns null when nothing is highlighted. */
  _hlBlock() {
    if (this._dangerLines.size === 0) return null;
    const rowH = this._rowH();
    let first = -1;
    let last = -1;
    for (let i3 = 0; i3 < this._visibleLines.length; i3++) {
      if (this._dangerLines.has(this._visibleLines[i3].line)) {
        if (first < 0) first = i3;
        last = i3;
      }
    }
    if (first < 0) return null;
    return {
      top: first * rowH,
      height: (last - first + 1) * rowH,
      color: this._highlightKind === "overwrite" ? "#58a6ff" : "#f48771"
    };
  }
  /** The 1px accent border shown while a member is highlighted for delete
   *  (red) or overwrite (blue). */
  _hlBorder() {
    const b$12 = this._hlBlock();
    if (!b$12) return A;
    return b`
      <div
        class="je-hl-border"
        style="top:${b$12.top}px; height:${b$12.height}px; --je-hl:${b$12.color}"
      ></div>
    `;
  }
  _clearDanger() {
    if (this._dangerLines.size === 0) return;
    this._dangerLines = /* @__PURE__ */ new Set();
    this._highlightKind = "delete";
    this.requestUpdate();
  }
  /** Map a mousedown on the textarea to an offset in `_visibleText`. */
  _clickedPos(e2) {
    const rowH = this._rowH();
    const idx = Math.floor(e2.offsetY / rowH);
    const v2 = this._visibleLines[Math.max(0, idx)];
    if (!v2) return 0;
    const lineStart = v2.start;
    const lineLen = v2.text.length;
    const cw = this._measureCharW() > 0 ? this._measureCharW() : 8;
    const col = Math.max(0, Math.floor((e2.offsetX - 10) / cw));
    return lineStart + Math.min(col, lineLen);
  }
  // ── Bracket matching (caret on a bracket highlights its pair) ────────────
  _updateBraceMatch(ta) {
    const text = this._visibleText;
    const pos = ta.selectionStart;
    const isBr = (c2) => c2 === "{" || c2 === "}" || c2 === "[" || c2 === "]";
    let idx = -1;
    if (isBr(text[pos])) idx = pos;
    else if (pos > 0 && isBr(text[pos - 1])) idx = pos - 1;
    const match = idx >= 0 ? this._bracketPair(text, idx) : -1;
    const next = match >= 0 ? [Math.min(idx, match), Math.max(idx, match)] : null;
    const same = next === null && this._braceMatch === null || next !== null && this._braceMatch !== null && next[0] === this._braceMatch[0] && next[1] === this._braceMatch[1];
    if (same) return;
    this._braceMatch = next;
    this.requestUpdate();
  }
  /** Find the index matching an opening/closing bracket (string-aware). */
  _bracketPair(text, idx) {
    const stack = [];
    const map = /* @__PURE__ */ new Map();
    let inStr = false;
    for (let i3 = 0; i3 < text.length; i3++) {
      const c2 = text[i3];
      if (inStr) {
        if (c2 === "\\") i3++;
        else if (c2 === '"') inStr = false;
        continue;
      }
      if (c2 === '"') inStr = true;
      else if (c2 === "{" || c2 === "[") stack.push(i3);
      else if (c2 === "}" || c2 === "]") {
        const o2 = stack.pop();
        if (o2 !== void 0) {
          map.set(o2, i3);
          map.set(i3, o2);
        }
      }
    }
    return map.get(idx) ?? -1;
  }
  // ── Key handling ─────────────────────────────────────────────────────────
  _onKeydown(e2) {
    if (this.readonly) return;
    const ta = e2.target;
    const key = e2.key;
    if (this._carets.length === 0 && e2.altKey && !e2.ctrlKey && !e2.metaKey && (key === "ArrowUp" || key === "ArrowDown")) {
      e2.preventDefault();
      e2.stopPropagation();
      this._moveLine(ta, key === "ArrowUp" ? -1 : 1);
      return;
    }
    if (this._carets.length === 0 && this._suggest) {
      if (key === "ArrowUp" || key === "ArrowDown") {
        e2.preventDefault();
        e2.stopPropagation();
        this._moveSuggestSelection(key === "ArrowUp" ? -1 : 1);
        return;
      }
      if (key === "Enter" || key === "Tab") {
        e2.preventDefault();
        e2.stopPropagation();
        this._acceptSuggest();
        return;
      }
      if (key === "Escape") {
        e2.preventDefault();
        e2.stopPropagation();
        this._dismissSuggest();
        return;
      }
      if (key === "ArrowLeft" || key === "ArrowRight") {
        e2.stopPropagation();
        this._hideSuggest();
        return;
      }
    }
    if ((e2.ctrlKey || e2.metaKey) && e2.altKey && (key === "ArrowUp" || key === "ArrowDown")) {
      e2.preventDefault();
      this._addCaretAboveBelow(key === "ArrowUp" ? -1 : 1);
      return;
    }
    if (this._carets.length > 0) {
      if (/^Arrow/.test(key)) {
        e2.preventDefault();
        this._moveAllCarets(key, e2.shiftKey, e2.metaKey || e2.ctrlKey);
        return;
      }
      if (key === "Enter") {
        e2.preventDefault();
        this._multiNewline();
        return;
      }
      if (key === "Tab") {
        e2.preventDefault();
        this._multiInsert("  ");
        return;
      }
      if (key === "Escape") {
        e2.preventDefault();
        this._carets = [];
        this._renderCarets();
        return;
      }
      return;
    }
    if ((e2.metaKey || e2.ctrlKey) && /^Arrow/.test(key)) {
      e2.preventDefault();
      this._singleCmdArrow(ta, key, e2.shiftKey);
      return;
    }
    if (key === "Enter") {
      e2.preventDefault();
      if (this._enterEmptyPair(ta)) {
        this._afterEdit(ta);
        return;
      }
      this._replaceRange(ta, ta.selectionStart, ta.selectionEnd, "\n" + this._indentAfter(ta));
      this._afterEdit(ta);
      return;
    }
    if (key === "Tab") {
      e2.preventDefault();
      this._replaceRange(ta, ta.selectionStart, ta.selectionEnd, "  ");
      this._afterEdit(ta);
      return;
    }
    if (key === "Backspace") {
      if (this._pairBackspace(ta)) {
        e2.preventDefault();
        this._afterEdit(ta);
      }
      return;
    }
    if (key === "{") {
      if (this._autoPair(ta, "{", "}")) {
        e2.preventDefault();
        this._afterEdit(ta);
      }
      return;
    }
    if (key === "[") {
      if (this._autoPair(ta, "[", "]")) {
        e2.preventDefault();
        this._afterEdit(ta);
      }
      return;
    }
    if (key === '"') {
      if (this._autoPairQuote(ta)) {
        e2.preventDefault();
        this._afterEdit(ta);
      }
      return;
    }
    if (key === "}" || key === "]") {
      if (this._skipOver(ta, key)) {
        e2.preventDefault();
        this._afterEdit(ta);
      }
    }
  }
  _selectableAt(pos) {
    for (const r2 of this._selectables) {
      if (pos >= r2.start && pos <= r2.end) return r2;
    }
    return null;
  }
  // ── JSON editing helpers ─────────────────────────────────────────────────
  _autoPair(ta, open, close) {
    if (ta.selectionStart !== ta.selectionEnd) return false;
    const pos = ta.selectionStart;
    this._replaceRange(ta, pos, pos, open + close);
    ta.setSelectionRange(pos + 1, pos + 1);
    return true;
  }
  _autoPairQuote(ta) {
    if (ta.selectionStart !== ta.selectionEnd) return false;
    const text = ta.value;
    const pos = ta.selectionStart;
    if (this._insideString(text, pos)) {
      if (text[pos] === '"') {
        ta.setSelectionRange(pos + 1, pos + 1);
        return true;
      }
      return false;
    }
    this._replaceRange(ta, pos, pos, '""');
    ta.setSelectionRange(pos + 1, pos + 1);
    return true;
  }
  _skipOver(ta, ch) {
    if (ta.value[ta.selectionStart] !== ch) return false;
    ta.setSelectionRange(ta.selectionStart + 1, ta.selectionStart + 1);
    return true;
  }
  _pairBackspace(ta) {
    const { selectionStart: s2, selectionEnd: e2, value } = ta;
    if (s2 !== e2 || s2 <= 0) return false;
    const open = value[s2 - 1];
    const close = value[s2];
    if (open === "{" && close === "}" || open === "[" && close === "]" || open === '"' && close === '"') {
      this._replaceRange(ta, s2 - 1, s2 + 1, "");
      ta.setSelectionRange(s2 - 1, s2 - 1);
      return true;
    }
    return false;
  }
  _indentAfter(ta) {
    return this._indentAt(ta.value, ta.selectionStart);
  }
  /** Enter inside an empty `[]`/`{}` pair expands it into a three-line block:
   *  the closing bracket moves onto its own line aligned with the opening
   *  line's indent, and the caret lands on a freshly-indented middle line
   *  ready for the first value. Returns true when handled. */
  _enterEmptyPair(ta) {
    const { selectionStart: s2, selectionEnd: e2, value } = ta;
    if (s2 !== e2 || s2 <= 0 || s2 >= value.length) return false;
    const open = value[s2 - 1];
    const close = value[s2];
    if (!(open === "[" && close === "]" || open === "{" && close === "}")) {
      return false;
    }
    const contentIndent = this._indentAt(value, s2);
    const closeIndent = this._indentAt(value, s2 - 1);
    const ins = `
${contentIndent}
${closeIndent}`;
    this._replaceRange(ta, s2, s2, ins);
    ta.setSelectionRange(s2 + 1 + contentIndent.length, s2 + 1 + contentIndent.length);
    return true;
  }
  _indentAt(text, pos) {
    const before = text.slice(0, pos);
    let depth = 0;
    let inStr = false;
    let escaped = false;
    for (let i3 = 0; i3 < before.length; i3++) {
      const c2 = before[i3];
      if (inStr) {
        if (escaped) escaped = false;
        else if (c2 === "\\") escaped = true;
        else if (c2 === '"') inStr = false;
        continue;
      }
      if (c2 === '"') inStr = true;
      else if (c2 === "{" || c2 === "[") depth++;
      else if (c2 === "}" || c2 === "]") depth = Math.max(0, depth - 1);
    }
    return "  ".repeat(depth);
  }
  // ── Custom caret rendering (file-editor style: 2px bar, blink) ───────────
  _inputEl() {
    return this.renderRoot.querySelector(".je-input");
  }
  _defaultCharW() {
    return this._measureCharW() > 0 ? this._measureCharW() : 7;
  }
  /** Exit multi-caret mode (collapse to the single primary hover). */
  _collapseMulti() {
    if (this._carets.length > 0) {
      this._carets = [];
      this._renderCarets();
    }
  }
  /** All caret ranges (primary + extras). Neither deduplicates carets that
   *  share a position nor sorts — callers render/merge every caret, and the
   *  edit helpers dedup identical ranges themselves while keeping the 1:1
   *  caret-to-result mapping. Callers that need an ordering sort locally. */
  _allCarets() {
    const ta = this._inputEl();
    let anchor;
    let pos;
    if (this._carets.length > 0) {
      anchor = this._primaryAnchor;
      pos = this._primaryPosition;
    } else {
      const s2 = (ta == null ? void 0 : ta.selectionStart) ?? 0;
      const e2 = (ta == null ? void 0 : ta.selectionEnd) ?? 0;
      if ((ta == null ? void 0 : ta.selectionDirection) === "backward") {
        anchor = e2;
        pos = s2;
      } else {
        anchor = s2;
        pos = e2;
      }
    }
    const out = [
      { s: Math.min(anchor, pos), e: Math.max(anchor, pos), pos }
    ];
    for (const c2 of this._carets) {
      const cs = Math.min(c2.anchor, c2.position);
      out.push({ s: cs, e: Math.max(c2.anchor, c2.position), pos: c2.position });
    }
    return out;
  }
  /** Render one `.je-caret` (2px bar) per caret, positioned over the text. */
  _renderCarets() {
    const layer = this.renderRoot.querySelector(".je-caret-layer");
    const ta = this._inputEl();
    if (!layer || !ta) return;
    layer.style.display = this._isFocused && !this.readonly ? "" : "none";
    if (layer.style.display === "none") return;
    const all = this._allCarets();
    while (this._caretEls.length < all.length) {
      const el = document.createElement("div");
      el.className = "je-caret";
      layer.appendChild(el);
      this._caretEls.push(el);
    }
    while (this._caretEls.length > all.length) {
      const el = this._caretEls.pop();
      el.remove();
    }
    const lh = this._rowH();
    const cw = this._defaultCharW();
    const vis = this._visibleText;
    for (let i3 = 0; i3 < all.length; i3++) {
      const el = this._caretEls[i3];
      const pos = all[i3].pos;
      const lineIdx = vis.slice(0, pos).split("\n").length - 1;
      const lineStart = lineIdx > 0 ? vis.lastIndexOf("\n", pos - 1) + 1 : 0;
      const col = pos - lineStart;
      el.style.left = 10 + col * cw + "px";
      el.style.top = lineIdx * lh + "px";
      el.style.height = lh + "px";
      el.style.opacity = this._caretVisible ? "1" : "0";
    }
  }
  _startCaretBlink() {
    if (this._caretRaf !== null || typeof requestAnimationFrame !== "function") return;
    const loop = () => {
      if (!this.isConnected) return;
      const phase = performance.now() % 1e3;
      const visible = phase < 500;
      if (visible !== this._caretVisible) {
        this._caretVisible = visible;
        for (const el of this._caretEls) el.style.opacity = visible ? "1" : "0";
      }
      this._caretRaf = requestAnimationFrame(loop);
    };
    this._caretRaf = requestAnimationFrame(loop);
  }
  _stopCaretBlink() {
    if (this._caretRaf !== null) cancelAnimationFrame(this._caretRaf);
    this._caretRaf = null;
    this._caretVisible = true;
    for (const el of this._caretEls) el.style.opacity = "1";
  }
  // ── Multi-caret editing ─────────────────────────────────────────────────
  _toggleCaret(pos) {
    const ta = this._inputEl();
    const i3 = this._carets.findIndex((c2) => c2.anchor === pos && c2.position === pos);
    if (i3 >= 0) {
      this._carets.splice(i3, 1);
    } else {
      if (this._carets.length === 0 && ta) {
        this._primaryAnchor = ta.selectionStart;
        this._primaryPosition = ta.selectionEnd;
      }
      this._carets.push({ anchor: pos, position: pos });
    }
    this._carets.sort((a2, b2) => a2.position - b2.position);
    this._renderCarets();
  }
  /** Ctrl+Alt+Up/Down — add a caret on the line above/below the primary. */
  _addCaretAboveBelow(dir) {
    const ta = this._inputEl();
    const primary = (ta == null ? void 0 : ta.selectionStart) ?? 0;
    const vis = this._visibleText;
    const lineIdx = vis.slice(0, primary).split("\n").length - 1;
    const lineStart = lineIdx > 0 ? vis.lastIndexOf("\n", primary - 1) + 1 : 0;
    const col = primary - lineStart;
    const target = lineIdx + dir;
    const lines = vis.split("\n");
    if (target < 0 || target >= lines.length) return;
    const targetLine = lines[target];
    const targetStart = lines.slice(0, target).reduce((a2, l2) => a2 + l2.length + 1, 0);
    const pos = targetStart + Math.min(col, targetLine.length);
    if (this._carets.length === 0) {
      this._primaryAnchor = primary;
      this._primaryPosition = (ta == null ? void 0 : ta.selectionEnd) ?? primary;
    }
    if (!this._carets.some((c2) => c2.position === pos)) {
      this._carets.push({ anchor: pos, position: pos });
      this._carets.sort((a2, b2) => a2.position - b2.position);
      this._renderCarets();
    }
  }
  /** Arrow keys in multi mode: delegate the movement/selection command to the
   *  shared CursorController, which applies it to EVERY caret (Shift extends
   *  each selection, Cmd jumps to line/document boundaries). The controller is
   *  seeded from the editor's folding-aware offset caret state and read back
   *  afterwards so the editor keeps ownership of its visible-buffer model. */
  _moveAllCarets(key, extend, cmd = false) {
    this._applyArrowCommand(
      [
        { anchor: this._primaryAnchor, position: this._primaryPosition },
        ...this._carets.map((c2) => ({ anchor: c2.anchor, position: c2.position }))
      ],
      key,
      extend,
      cmd
    );
  }
  /** Single-caret Cmd/Ctrl+Arrow: drive the line/document-boundary move through
   *  the engine too, so the custom caret + selection track the active end
   *  (native textarea Cmd+arrow is unreliable across platforms). */
  _singleCmdArrow(ta, key, extend) {
    const backward = ta.selectionDirection === "backward";
    const s2 = ta.selectionStart;
    const e2 = ta.selectionEnd;
    const anchor = backward ? e2 : s2;
    const position = backward ? s2 : e2;
    this._applyArrowCommand([{ anchor, position }], key, extend, true);
  }
  /** Seed a fresh CursorController from offset caret states, dispatch one arrow
   *  command, then write the results back to the primary + extras and refresh
   *  the selection/caret layers. */
  _applyArrowCommand(seed, key, extend, cmd) {
    const ta = this._inputEl();
    if (!ta) return;
    const controller = new CursorController(
      new PieceTreeTextContentModel("json-editor", this._visibleText)
    );
    controller.setCursorStates(
      seed.map((c2) => ({
        position: this._posAt(c2.position),
        selectionAnchor: this._posAt(c2.anchor)
      }))
    );
    this._applyCursorOp(controller, key, extend, cmd);
    const all = controller.getAllCursors();
    this._primaryAnchor = this._offsetAt(all[0].selectionAnchor);
    this._primaryPosition = this._offsetAt(all[0].position);
    this._carets = all.slice(1).map((c2) => ({
      anchor: this._offsetAt(c2.selectionAnchor),
      position: this._offsetAt(c2.position)
    }));
    ta.setSelectionRange(
      Math.min(this._primaryAnchor, this._primaryPosition),
      Math.max(this._primaryAnchor, this._primaryPosition),
      this._primaryPosition < this._primaryAnchor ? "backward" : "forward"
    );
    this._updateBraceMatch(ta);
    this._updateSelectionHighlight();
    this._syncActiveLine();
    this._renderCarets();
  }
  /** Dispatch an arrow command onto the shared cursor controller. Cmd+arrow
   *  jumps to line/document boundaries; plain arrows step; Shift extends. */
  _applyCursorOp(controller, key, extend, cmd) {
    if (cmd) {
      switch (key) {
        case "ArrowLeft":
          extend ? controller.selectToLineStart() : controller.moveToLineStart();
          break;
        case "ArrowRight":
          extend ? controller.selectToLineEnd() : controller.moveToLineEnd();
          break;
        case "ArrowUp":
          extend ? controller.selectToFileStart() : controller.moveToFileStart();
          break;
        case "ArrowDown":
          extend ? controller.selectToFileEnd() : controller.moveToFileEnd();
          break;
      }
    } else {
      switch (key) {
        case "ArrowLeft":
          extend ? controller.selectLeft() : controller.moveLeft();
          break;
        case "ArrowRight":
          extend ? controller.selectRight() : controller.moveRight();
          break;
        case "ArrowUp":
          extend ? controller.selectUp() : controller.moveUp();
          break;
        case "ArrowDown":
          extend ? controller.selectDown() : controller.moveDown();
          break;
      }
    }
  }
  /** Offset → 1-based line/column position within the visible buffer. */
  _posAt(offset) {
    const text = this._visibleText;
    const clamped = Math.max(0, Math.min(offset, text.length));
    const lineIdx = text.slice(0, clamped).split("\n").length - 1;
    const lineStart = lineIdx > 0 ? text.lastIndexOf("\n", clamped - 1) + 1 : 0;
    return { lineNumber: lineIdx + 1, column: clamped - lineStart + 1 };
  }
  /** 1-based line/column position → offset within the visible buffer. */
  _offsetAt(position) {
    const lines = this._visibleText.split("\n");
    let off = 0;
    const last = Math.max(0, position.lineNumber - 1);
    for (let i3 = 0; i3 < last && i3 < lines.length; i3++) off += lines[i3].length + 1;
    return off + Math.max(0, position.column - 1);
  }
  /** Apply a (visible-text) edit result across every caret, then rebuild. */
  _applyMultiResult(out, newPos) {
    this._applyVisible(out);
    const primary = newPos[0] ?? 0;
    this._carets = newPos.slice(1).map((p2) => ({ anchor: p2, position: p2 }));
    this._primaryAnchor = primary;
    this._primaryPosition = primary;
    const ta = this._inputEl();
    if (ta) {
      ta.value = this._visibleText;
      ta.setSelectionRange(primary, primary);
    }
    this._ensureCaretVisible();
    if (ta) this._updateBraceMatch(ta);
    this._syncActiveLine();
    this._updateSelectionHighlight();
    this._renderCarets();
  }
  /** Apply an edit at every caret via a per-caret mutator. Carets that share
   *  the same span (e.g. after Cmd+ArrowUp converged them to one position)
   *  are edited ONCE, but every caret still maps to its own result position
   *  so the caret count and both carets' presence persist. */
  _multiEdit(mutate) {
    const carets = this._allCarets();
    const vis = this._visibleText;
    const seen = /* @__PURE__ */ new Set();
    const edits = [];
    const resultByKey = /* @__PURE__ */ new Map();
    for (const c2 of carets) {
      const key = `${c2.s}:${c2.e}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const r2 = mutate(c2.s, c2.e, vis);
      edits.push({ delStart: r2.delStart, delEnd: r2.delEnd, ins: r2.ins, s: c2.s });
      resultByKey.set(key, r2.result);
    }
    edits.sort((a2, b2) => b2.s - a2.s);
    let out = vis;
    for (const ed of edits) {
      out = out.slice(0, ed.delStart) + ed.ins + out.slice(ed.delEnd);
    }
    const newPos = carets.map((c2) => resultByKey.get(`${c2.s}:${c2.e}`));
    this._applyMultiResult(out, newPos);
  }
  /** Insert `data` at every caret (with JSON auto-pair for braces/quotes). */
  _multiInsert(data) {
    this._multiEdit((s2, e2, vis) => {
      let ins = data;
      let off = data.length;
      if (data === "{" || data === "[") {
        ins = data + (data === "{" ? "}" : "]");
        off = 1;
      } else if (data === '"') {
        if (this._insideString(vis, e2)) ins = '"';
        else ins = '""';
        off = 1;
      } else if (data === "}" || data === "]") {
        if (e2 === s2 && vis[e2] === data) {
          ins = "";
          off = 1;
        } else {
          ins = data;
          off = 1;
        }
      }
      return { ins, delStart: s2, delEnd: e2, result: s2 + off };
    });
  }
  /** Backspace at every caret (deleting a selection, or an adjacent pair). */
  _multiBackspace() {
    this._multiEdit((s2, e2, vis) => {
      if (e2 > s2) return { ins: "", delStart: s2, delEnd: e2, result: s2 };
      if (s2 <= 0) return { ins: "", delStart: s2, delEnd: s2, result: 0 };
      const open = vis[s2 - 1];
      const close = vis[s2];
      const pair = open === "{" && close === "}" || open === "[" && close === "]" || open === '"' && close === '"';
      if (pair) return { ins: "", delStart: s2 - 1, delEnd: s2 + 1, result: s2 - 1 };
      return { ins: "", delStart: s2 - 1, delEnd: s2, result: s2 - 1 };
    });
  }
  /** Delete-forward at every caret. */
  _multiDelete() {
    this._multiEdit((s2, e2, vis) => {
      if (e2 > s2) return { ins: "", delStart: s2, delEnd: e2, result: s2 };
      if (s2 >= vis.length) return { ins: "", delStart: s2, delEnd: s2, result: s2 };
      return { ins: "", delStart: s2, delEnd: s2 + 1, result: s2 };
    });
  }
  /** Enter at every caret (newline + auto-indent). */
  _multiNewline() {
    this._multiEdit((s2, _e, vis) => {
      if (s2 > 0 && s2 < vis.length) {
        const open = vis[s2 - 1];
        const close = vis[s2];
        if (open === "[" && close === "]" || open === "{" && close === "}") {
          const ci = this._indentAt(vis, s2);
          const cli = this._indentAt(vis, s2 - 1);
          const ins2 = `
${ci}
${cli}`;
          return { ins: ins2, delStart: s2, delEnd: s2, result: s2 + 1 + ci.length };
        }
      }
      const ins = "\n" + this._indentAt(vis, s2);
      return { ins, delStart: s2, delEnd: s2, result: s2 + ins.length };
    });
  }
  _insideString(text, pos) {
    let inStr = false;
    let escaped = false;
    for (let i3 = 0; i3 < pos; i3++) {
      const c2 = text[i3];
      if (escaped) escaped = false;
      else if (c2 === "\\") escaped = true;
      else if (c2 === '"') inStr = !inStr;
    }
    return inStr;
  }
  _replaceRange(ta, start, end, text) {
    ta.setRangeText(text, start, end, "end");
  }
  /** Alt/Option+ArrowUp/Down — swap the caret's current line with the line
   *  above/below (VS Code), keeping the caret at the same column on the moved
   *  line. Operates on the visible text (the textarea value); `_afterEdit`
   *  reconciles the change with the full/parsed text. */
  _moveLine(ta, dir) {
    const value = ta.value;
    const caret = ta.selectionStart;
    const lineStart = value.lastIndexOf("\n", caret - 1) + 1;
    const col = caret - lineStart;
    let lineIdx = 0;
    for (let i3 = 0; i3 < caret; i3++) if (value[i3] === "\n") lineIdx++;
    const units = [];
    let last = 0;
    for (let i3 = 0; i3 < value.length; i3++) {
      if (value[i3] === "\n") {
        units.push(value.slice(last, i3 + 1));
        last = i3 + 1;
      }
    }
    if (last < value.length) units.push(value.slice(last));
    const target = lineIdx + dir;
    if (target < 0 || target >= units.length) return;
    const tmp = units[lineIdx];
    units[lineIdx] = units[target];
    units[target] = tmp;
    const newVal = units.join("");
    ta.value = newVal;
    let movedStart = 0;
    for (let i3 = 0; i3 < target; i3++) movedStart += units[i3].length;
    const movedLen = units[target].endsWith("\n") ? Math.max(0, units[target].length - 1) : units[target].length;
    ta.setSelectionRange(
      movedStart + Math.min(col, movedLen),
      movedStart + Math.min(col, movedLen)
    );
    this._afterEdit(ta);
  }
};
JsonEditorElement.styles = i$4`
    ${r$5(GUTTER_DEFAULT_CSS)}
    :host {
      display: block;
      box-sizing: border-box;
      height: 100%;
      overflow: hidden;
      color: var(--text-primary, #d4d4d4);
      font-family: ui-monospace, "Cascadia Code", "Fira Code", Menlo, Consolas, monospace;
      font-size: var(--je-font-size, 13px);
      background: var(--bg-primary, #1e1e1e);
      text-align: left;
    }
    :host ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }
    :host ::-webkit-scrollbar-track {
      background: transparent;
    }
    :host ::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.16);
      border-radius: 0;
    }
    :host ::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.34);
    }

    .je-root {
      display: flex;
      flex-direction: column;
      height: 100%;
      min-height: 0;
    }
    .je-viewport {
      flex: 1 1 auto;
      min-height: 0;
      overflow: auto;
      position: relative;
      background: var(--bg-primary, #1e1e1e);
    }
    .je-inner {
      display: flex;
      align-items: stretch;
      width: 100%;
      min-width: max-content;
      min-height: 100%;
      position: relative;
    }
    /* The gutter is provided by openp41ge-core-editor-gutter (generic 'eg-*'
       classes); the JSON editor styles it to match the file editor. The
       'eg-gutter' host is sticky-left and shrink-wraps its columns. */
    .je-gutter-mount {
      display: contents;
    }
    .eg-gutter {
      position: sticky;
      left: 0;
      z-index: 2;
      display: flex;
      align-items: stretch;
      flex: 0 0 auto;
      background: var(--bg-primary, #1e1e1e);
      user-select: none;
      /* Line-number text — match the file editor (its numbers inherit
         text-primary), not the dimmer text-secondary. */
      color: var(--text-primary, #d4d4d4);
      font-size: 11px;
      /* Colour tokens for the shared gutter default styles (GUTTER_DEFAULT_CSS). */
      --eg-fold-color: var(--je-fold-color, #79c0ff);
    }
    /* Editor-specific gutter bits on top of GUTTER_DEFAULT_CSS: the shared
       default provides cell layout, the fold-cell/chevron structure and the
       unified hover box; the JSON editor only themes it and styles its
       line-number cells. Scoped to the line-number column so the fold
       chevron button keeps the shared centered, full-cell layout. */
    .eg-col--line-numbers .eg-cell {
      justify-content: flex-end;
      padding: 0 8px;
      cursor: pointer;
    }
    .eg-cell {
      transition: background-color 120ms ease;
    }
    /* Error line numbers keep their red tint; the unified hover box merely
       sits over them (below). */
    .eg-cell--err {
      background: rgba(244, 135, 113, 0.28);
      color: #f48771;
    }
    /* The caret's line-number cell (active gutter row) — matches the file
       editor's active-line highlight. Painted by the gutter host when the
       caret moves; kept subtle so error/fold cells still read clearly. */
    .eg-cell.eg-cell--active {
      background: var(--je-active-line-bg, rgba(255, 255, 255, 0.12));
    }

    /* Schema tooltip — shown on key hover. Positioned by the editor near
       the hovered key token; content comes from the JSON Schema property
       "description". */
    .je-tooltip {
      position: absolute;
      z-index: 30;
      max-width: 665px;
      box-sizing: border-box;
      padding: 6px 9px;
      font-size: 12px;
      line-height: 1.5;
      color: var(--text-primary, #d4d4d4);
      background: var(--bg-secondary, #252526);
      border: 1px solid var(--divider, #454545);
      border-radius: 6px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.45);
      white-space: normal;
      pointer-events: none;
      display: none;
    }
    /* Rendered Markdown inside the tooltip (schema descriptions + loaded
       resource files). Text outside recognised markers is escaped by the
       renderer, so only these elements carry content. */
    .je-tooltip p {
      margin: 0 0 6px;
    }
    .je-tooltip p:last-child {
      margin-bottom: 0;
    }
    .je-tooltip h1,
    .je-tooltip h2,
    .je-tooltip h3,
    .je-tooltip h4 {
      margin: 6px 0 4px;
      font-weight: 600;
      line-height: 1.3;
    }
    .je-tooltip h1 {
      font-size: 15px;
    }
    .je-tooltip h2 {
      font-size: 14px;
    }
    .je-tooltip h3,
    .je-tooltip h4 {
      font-size: 13px;
    }
    .je-tooltip ul,
    .je-tooltip ol {
      margin: 4px 0;
      padding-left: 18px;
    }
    .je-tooltip li {
      margin: 2px 0;
    }
    .je-tooltip blockquote {
      margin: 6px 0;
      padding: 2px 8px;
      border-left: 3px solid var(--divider, #454545);
      color: var(--text-secondary, #9d9d9d);
    }
    .je-tooltip hr {
      border: 0;
      border-top: 1px solid var(--divider, #454545);
      margin: 8px 0;
    }
    .je-tooltip pre.je-md-code {
      margin: 6px 0;
      padding: 6px 8px;
      background: rgba(0, 0, 0, 0.3);
      border: 1px solid var(--divider, #454545);
      border-radius: 4px;
      overflow-x: auto;
      white-space: pre;
      font-family: var(--font-mono, monospace);
      font-size: 11px;
      line-height: 1.45;
    }
    .je-tooltip pre.je-md-code code {
      background: none;
      padding: 0;
      font-size: inherit;
    }
    .je-tooltip code {
      background: rgba(255, 255, 255, 0.12);
      padding: 1px 3px;
      border-radius: 3px;
      font-family: var(--font-mono, monospace);
      font-size: 11px;
    }
    .je-tooltip a {
      color: var(--accent, #4da3ff);
    }
    .je-tooltip .je-tooltip-hint {
      margin-top: 6px;
      font-size: 11px;
      color: var(--text-secondary, #9d9d9d);
    }

    .je-content {
      position: relative;
      flex: 1 1 auto;
      min-width: max-content;
    }
    /* Key auto-complete list — appears below the caret when it sits inside a
       key-position string. Shows the schema keys not already set at that
       object; the highlighted row is the one Up/Down will accept. */
    .je-suggest {
      position: absolute;
      z-index: 40;
      box-sizing: border-box;
      min-width: 180px;
      max-width: 340px;
      max-height: 220px;
      overflow-y: auto;
      padding: 4px;
      background: var(--bg-secondary, #252526);
      border: 1px solid var(--divider, #454545);
      border-radius: 6px;
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.5);
      color: var(--text-primary, #d4d4d4);
      font-size: 13px;
      line-height: 1.4;
    }
    .je-suggest-item {
      height: 24px;
      line-height: 24px;
      padding: 0 8px;
      border-radius: 4px;
      cursor: pointer;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .je-suggest-item--sel {
      background: var(--je-suggest-sel-bg, rgba(38, 79, 120, 0.9));
      color: var(--je-suggest-sel-fg, #ffffff);
    }
    /* Thin side tooltip next to the list — same text as the key hover tooltip
       for the highlighted suggestion. */
    .je-suggest-tip {
      position: absolute;
      z-index: 41;
      box-sizing: border-box;
      max-width: 320px;
      padding: 4px 8px;
      font-size: 12px;
      line-height: 1.5;
      color: var(--text-primary, #d4d4d4);
      background: var(--bg-secondary, #252526);
      border: 1px solid var(--divider, #454545);
      border-radius: 6px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.45);
      white-space: pre-wrap;
      pointer-events: none;
    }
    .je-lines {
      position: relative;
      white-space: normal;
    }
    /* Rounded selection highlight layer (Monaco-style). It sits behind the
       line text: outer corners get border-radius, inner (wrap) corners get
       small background-colored notches. */
    .je-selection {
      position: absolute;
      inset: 0;
      z-index: 0;
      pointer-events: none;
    }
    .je-segment {
      position: absolute;
      background: var(--je-selection-bg, rgba(38, 79, 120, 0.75));
      pointer-events: none;
      z-index: 1;
    }
    .je-segment.top-left-radius {
      border-top-left-radius: 3px;
    }
    .je-segment.top-right-radius {
      border-top-right-radius: 3px;
    }
    .je-segment.bottom-left-radius {
      border-bottom-left-radius: 3px;
    }
    .je-segment.bottom-right-radius {
      border-bottom-right-radius: 3px;
    }
    .je-corner-piece {
      position: absolute;
      background: var(--je-selection-bg, rgba(38, 79, 120, 0.85));
      pointer-events: none;
      z-index: 2;
    }
    .je-notch {
      position: absolute;
      background: var(--je-bg, var(--bg-primary, #1e1e1e));
      pointer-events: none;
      z-index: 3;
    }
    .je-notch.top-right-radius {
      border-top-right-radius: 3px;
    }
    .je-notch.bottom-right-radius {
      border-bottom-right-radius: 3px;
    }
    .je-notch.top-left-radius {
      border-top-left-radius: 3px;
    }
    .je-notch.bottom-left-radius {
      border-bottom-left-radius: 3px;
    }
    .je-row {
      position: relative;
      display: flex;
      align-items: stretch;
      height: var(--je-row-height, 20px);
    }
    .je-row--danger {
      background: rgba(244, 135, 113, 0.22);
    }
    .je-row--overwrite {
      background: rgba(88, 166, 255, 0.22);
    }
    /* 1px accent border around a highlighted member block (delete/overwrite
       hover). */
    .je-hl-border {
      position: absolute;
      left: 0;
      right: 0;
      z-index: 30;
      box-sizing: border-box;
      border: 1px solid var(--je-hl, #f48771);
      pointer-events: none;
    }
    .je-row--faded .je-line {
      opacity: 0.38;
    }
    .je-row--faded .je-line:hover {
      opacity: 0.6;
    }
    .je-line {
      flex: 1 1 auto;
      min-width: 0;
      height: var(--je-row-height, 20px);
      line-height: var(--je-row-height, 20px);
      padding: 0 10px;
      box-sizing: border-box;
      white-space: pre;
      overflow: hidden;
    }
    .je-fold-meta {
      color: var(--text-secondary, #6e7681);
    }
    .je-brace--match {
      background: rgba(121, 192, 255, 0.22);
      color: #a5d6ff;
      border-radius: 2px;
    }
    .je-actions {
      z-index: 3;
      flex: 0 0 26px;
      width: 26px;
      display: flex;
      align-items: center;
      justify-content: flex-end;
      padding-right: 4px;
      box-sizing: border-box;
      pointer-events: none;
    }
    .je-del {
      pointer-events: auto;
      border: none;
      background: transparent;
      color: var(--text-secondary, #6e7681);
      font: inherit;
      font-size: 14px;
      line-height: 1;
      cursor: pointer;
      padding: 2px;
      opacity: 0;
      transition: opacity 0.12s ease;
    }
    .je-del--show {
      opacity: 1;
    }
    .je-del:hover {
      opacity: 1;
      color: #f48771;
    }
    /* Overwrite (pin this default into user config) button on faded rows. */
    .je-ow {
      pointer-events: auto;
      border: none;
      background: transparent;
      color: var(--text-secondary, #6e7681);
      font: inherit;
      line-height: 1;
      cursor: pointer;
      padding: 3px;
      display: flex;
      align-items: center;
      justify-content: center;
      opacity: 0;
      transition: opacity 0.12s ease;
    }
    .je-ow svg {
      stroke: currentColor;
    }
    .je-ow--show {
      opacity: 1;
    }
    .je-ow:hover {
      color: #58a6ff;
      background: var(--bg-active, #37373d);
      border-radius: 3px;
    }

    textarea.je-input {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      box-sizing: border-box;
      margin: 0;
      padding: 0 10px;
      border: none;
      outline: none;
      resize: none;
      background: transparent;
      color: transparent;
      caret-color: transparent;
      font: inherit;
      line-height: var(--je-row-height, 20px);
      white-space: pre;
      overflow: hidden;
      word-break: keep-all;
      overscroll-behavior: contain;
      z-index: 1;
      /* The global app shell sets body { user-select: none }; an editor
         must re-enable it or Chromium will not place a caret / select text.
         The native caret + selection are hidden (transparent + ::selection),
         the visible caret/selection are drawn by the custom layers, but the
         underlying placements still need user-select to be selectable - the
         file editor does the same (user-select: text on its viewport). */
      user-select: text;
      -webkit-user-select: text;
    }
    textarea.je-input::selection {
      background: transparent;
      color: transparent;
      -webkit-text-fill-color: transparent;
    }
    /* Custom caret layer — the native textarea caret is hidden and carets
       are rendered here as 2px blinking bars, matching the file editor. */
    .je-caret-layer {
      position: absolute;
      inset: 0;
      z-index: 2;
      pointer-events: none;
    }
    .je-caret {
      position: absolute;
      left: 0;
      top: 0;
      width: 2px;
      background: var(--fe-cursor-color, #d4d4d4);
      pointer-events: none;
    }

    .s-str {
      color: #ce9178;
    }
    .s-var {
      color: #9cdcfe;
    }
    .s-num {
      color: #b5cea8;
    }
    .s-kw {
      color: #569cd6;
    }
    .s-pun {
      color: #d4d4d4;
    }
    .je-key,
    .je-value {
      border-radius: 2px;
    }
  `;
__decorateClass([
  n2({ attribute: false })
], JsonEditorElement.prototype, "value", 2);
__decorateClass([
  n2({ type: Boolean, attribute: "readonly" })
], JsonEditorElement.prototype, "readonly", 2);
__decorateClass([
  n2({ type: Number, attribute: "row-height" })
], JsonEditorElement.prototype, "rowHeight", 2);
__decorateClass([
  n2({ type: Number, attribute: "font-size" })
], JsonEditorElement.prototype, "fontSize", 2);
__decorateClass([
  n2({ attribute: false })
], JsonEditorElement.prototype, "schema", 2);
__decorateClass([
  n2({ attribute: false })
], JsonEditorElement.prototype, "resolveResource", 2);
__decorateClass([
  n2({ attribute: false })
], JsonEditorElement.prototype, "defaults", 2);
__decorateClass([
  n2({ type: Boolean, attribute: "show-defaults" })
], JsonEditorElement.prototype, "showDefaults", 2);
__decorateClass([
  n2({ attribute: false })
], JsonEditorElement.prototype, "explicitPaths", 2);
__decorateClass([
  r$1()
], JsonEditorElement.prototype, "_text", 2);
__decorateClass([
  r$1()
], JsonEditorElement.prototype, "_hoverLine", 2);
__decorateClass([
  r$1()
], JsonEditorElement.prototype, "_suggest", 2);
JsonEditorElement = __decorateClass([
  t$1("json-editor")
], JsonEditorElement);
const CONFIG_TYPES = ["object", "array", "string", "number", "integer", "boolean", "null"];
function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
function clone(value) {
  return value === void 0 ? value : JSON.parse(JSON.stringify(value));
}
function at(path, key) {
  return path ? `${path}.${key}` : key;
}
function prefix(path, message) {
  return path ? `${path}: ${message}` : message;
}
function validateConfigSchema(schema) {
  if (!isPlainObject(schema) || schema.type !== "object") {
    throw new Error('config schema: the root must be an object schema ({ type: "object" })');
  }
  checkSchema(schema, "");
  return schema;
}
function checkSchema(schema, path) {
  const fail = (message) => {
    throw new Error(`config schema: ${prefix(path, message)}`);
  };
  if (schema.type !== void 0) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    const unknown = types.find((t2) => !CONFIG_TYPES.includes(t2));
    if (unknown !== void 0 || types.length === 0) {
      fail(`unknown type ${JSON.stringify(unknown)}`);
    }
  }
  if (schema.properties !== void 0) {
    if (!isPlainObject(schema.properties)) fail("properties must be an object");
    for (const [key, sub] of Object.entries(schema.properties)) {
      if (!isPlainObject(sub)) fail(`${at(path, key)} must be a schema`);
      checkSchema(sub, at(path, key));
    }
  }
  if (schema.items !== void 0) {
    if (!isPlainObject(schema.items)) fail("items must be a schema");
    checkSchema(schema.items, `${path}[]`);
  }
  if (isPlainObject(schema.additionalProperties)) {
    checkSchema(schema.additionalProperties, at(path, "*"));
  }
  if (schema.required !== void 0 && !(Array.isArray(schema.required) && schema.required.every((r2) => typeof r2 === "string"))) {
    fail("required must be a list of names");
  }
  if (schema.enum !== void 0 && !Array.isArray(schema.enum)) fail("enum must be a list");
  if (schema.default !== void 0) {
    const errors = configErrors(schema, schema.default);
    if (errors.length > 0) fail(`default: ${errors[0]}`);
  }
}
function configDefaults(schema) {
  const out = {};
  for (const [key, sub] of Object.entries(schema.properties ?? {})) {
    if (sub.default !== void 0) {
      out[key] = clone(sub.default);
    } else if (sub.properties) {
      const nested = configDefaults(sub);
      if (Object.keys(nested).length > 0) out[key] = nested;
    }
  }
  return out;
}
function typeMatches(type, value) {
  switch (type) {
    case "object":
      return isPlainObject(value);
    case "array":
      return Array.isArray(value);
    case "integer":
      return typeof value === "number" && Number.isInteger(value);
    case "null":
      return value === null;
    default:
      return typeof value === type;
  }
}
function configErrors(schema, value, path = "") {
  if (schema.type) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.some((t2) => typeMatches(t2, value))) {
      return [prefix(path, `expected ${types.join(" or ")}`)];
    }
  }
  const errors = [];
  if (schema.enum && !schema.enum.some((e2) => JSON.stringify(e2) === JSON.stringify(value))) {
    errors.push(
      prefix(path, `must be one of ${schema.enum.map((e2) => JSON.stringify(e2)).join(", ")}`)
    );
  }
  if (typeof value === "number") {
    if (schema.minimum !== void 0 && value < schema.minimum) {
      errors.push(prefix(path, `must be at least ${schema.minimum}`));
    }
    if (schema.maximum !== void 0 && value > schema.maximum) {
      errors.push(prefix(path, `must be at most ${schema.maximum}`));
    }
  }
  if (Array.isArray(value) && schema.items) {
    value.forEach((item, i3) => errors.push(...configErrors(schema.items, item, `${path}[${i3}]`)));
  }
  if (isPlainObject(value)) {
    const properties = schema.properties ?? {};
    for (const name of schema.required ?? []) {
      if (value[name] === void 0) errors.push(`${at(path, name)}: is required`);
    }
    for (const [key, item] of Object.entries(value)) {
      const sub = properties[key];
      if (sub) {
        errors.push(...configErrors(sub, item, at(path, key)));
      } else if (schema.additionalProperties === false) {
        errors.push(`${at(path, key)}: is not allowed`);
      } else if (isPlainObject(schema.additionalProperties)) {
        errors.push(...configErrors(schema.additionalProperties, item, at(path, key)));
      }
    }
  }
  return errors;
}
function mergeConfig(defaults, overrides) {
  const out = clone(defaults);
  for (const [key, value] of Object.entries(overrides)) {
    if (value === void 0) continue;
    out[key] = isPlainObject(value) && isPlainObject(out[key]) ? mergeConfig(out[key], value) : clone(value);
  }
  return out;
}
export {
  JSON_EDITOR_CHANGE,
  JsonEditorElement,
  configDefaults,
  configErrors,
  mergeConfig,
  mergeDefaults,
  setJsonEditorDefaults,
  stripDefaults,
  validateConfigSchema
};
