module.exports = ah(async (req, res) => {
  const { amount, memo, tip } = req.body;

  try {
    if (config.lna.clightning) {
      const invoice = await lna.invoice(`${amount + tip}sat` || "any", new Date(), memo, 360);
      res.send(invoice.bolt11);
    } else {
      const invoice = await lna.addInvoice({ value: amount + tip, memo });
      res.send(invoice.payment_request);
    }
  } catch (e) {
    l.error("problem creating invoice", e.message);
    res.status(500).send(e.message);
  }
});
