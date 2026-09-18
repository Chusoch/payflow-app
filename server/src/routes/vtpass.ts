import { Router, Response } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { config } from '../config';
import { handleVtpassPay, handleVtpassRequery, handleMerchantVerify } from '../services/vtpass';

const router = Router();



const MOCK_DATA_PLANS: Record<string, any[]> = {
  mtn: [
    { variation_code: 'mtn-500mb-300', name: 'MTN 500MB Data Plan', variation_amount: '300', validity: '1 Day' },
    { variation_code: 'mtn-1.5gb-1000', name: 'MTN 1.5GB Data Plan', variation_amount: '1000', validity: '30 Days' },
    { variation_code: 'mtn-3gb-1500', name: 'MTN 3GB Data Plan', variation_amount: '1500', validity: '30 Days' },
    { variation_code: 'mtn-5gb-2500', name: 'MTN 5GB Data Plan', variation_amount: '2500', validity: '30 Days' },
    { variation_code: 'mtn-10gb-5000', name: 'MTN 10GB Data Plan', variation_amount: '5000', validity: '30 Days' },
  ],
  glo: [
    { variation_code: 'glo-1gb-1000', name: 'GLO 1GB Data Plan', variation_amount: '1000', validity: '30 Days' },
    { variation_code: 'glo-2.5gb-1500', name: 'GLO 2.5GB Data Plan', variation_amount: '1500', validity: '30 Days' },
    { variation_code: 'glo-5.8gb-2500', name: 'GLO 5.8GB Data Plan', variation_amount: '2500', validity: '30 Days' },
    { variation_code: 'glo-10gb-4000', name: 'GLO 10GB Data Plan', variation_amount: '4000', validity: '30 Days' },
  ],
  airtel: [
    { variation_code: 'airtel-750mb-500', name: 'Airtel 750MB Data Plan', variation_amount: '500', validity: '14 Days' },
    { variation_code: 'airtel-1.5gb-1000', name: 'Airtel 1.5GB Data Plan', variation_amount: '1000', validity: '30 Days' },
    { variation_code: 'airtel-3gb-1500', name: 'Airtel 3GB Data Plan', variation_amount: '1500', validity: '30 Days' },
    { variation_code: 'airtel-4.5gb-2000', name: 'Airtel 4.5GB Data Plan', variation_amount: '2000', validity: '30 Days' },
  ],
  '9mobile': [
    { variation_code: '9mobile-1gb-1000', name: '9mobile 1GB Data Plan', variation_amount: '1000', validity: '30 Days' },
    { variation_code: '9mobile-2.5gb-1500', name: '9mobile 2.5GB Data Plan', variation_amount: '1500', validity: '30 Days' },
    { variation_code: '9mobile-4.5gb-2000', name: '9mobile 4.5GB Data Plan', variation_amount: '2000', validity: '30 Days' },
    { variation_code: '9mobile-11gb-4000', name: '9mobile 11GB Data Plan', variation_amount: '4000', validity: '30 Days' },
  ],
};

/**
 * GET /v1/vtpass/services?identifier=airtime|data
 * Proxy VTPass service-categories endpoint. Requires authentication.
 */
router.get('/services', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const identifier = (req.query.identifier as string) || 'airtime';

  if (config.vtpassApiKey && config.vtpassSecretKey) {
    try {
      const response = await fetch(`${config.vtpassBaseUrl}/service-categories?identifier=${identifier}`, {
        headers: {
          'api-key': config.vtpassApiKey!,
          'secret-key': config.vtpassSecretKey!,
        },
      });

      const data = await response.json();
      res.status(response.status).json(data);
      return;
    } catch (err: any) {
      res.status(502).json({ response_description: `VTPass Gateway Error: ${err?.message || 'Upstream connection failed'}` });
      return;
    }
  }

  // Mock / Sandbox response
  const isData = identifier.toLowerCase() === 'data';
  res.status(200).json({
    code: '000',
    content: isData
      ? [
          { serviceID: 'mtn-data', name: 'MTN Data' },
          { serviceID: 'glo-data', name: 'GLO Data' },
          { serviceID: 'airtel-data', name: 'Airtel Data' },
          { serviceID: 'etisalat-data', name: '9mobile Data' },
        ]
      : [
          { serviceID: 'mtn', name: 'MTN Airtime' },
          { serviceID: 'glo', name: 'GLO Airtime' },
          { serviceID: 'airtel', name: 'Airtel Airtime' },
          { serviceID: 'etisalat', name: '9mobile Airtime' },
        ],
  });
});

/**
 * GET /v1/vtpass/data-plans?network=mtn|glo|airtel|9mobile
 * Proxy VTPass service-variations for mobile data plans. Requires authentication.
 */
router.get('/data-plans', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const network = ((req.query.network as string) || 'mtn').toLowerCase();
  const serviceIdMap: Record<string, string> = {
    mtn: 'mtn-data',
    glo: 'glo-data',
    airtel: 'airtel-data',
    '9mobile': 'etisalat-data',
    etisalat: 'etisalat-data',
  };

  const serviceID = serviceIdMap[network] || 'mtn-data';

  if (config.vtpassApiKey && config.vtpassSecretKey) {
    try {
      const response = await fetch(`${config.vtpassBaseUrl}/service-variations?serviceID=${serviceID}`, {
        headers: {
          'api-key': config.vtpassApiKey!,
          'secret-key': config.vtpassSecretKey!,
        },
      });

      const data = await response.json();
      res.status(response.status).json(data);
      return;
    } catch (err: any) {
      res.status(502).json({ response_description: `VTPass Gateway Error: ${err?.message || 'Upstream connection failed'}` });
      return;
    }
  }

  const variations = MOCK_DATA_PLANS[network] || MOCK_DATA_PLANS.mtn;

  res.status(200).json({
    response_description: '000',
    content: {
      ServiceName: `${network.toUpperCase()} Data`,
      serviceID,
      conveniency_fee: '0 %',
      varations: variations,
    },
  });
});

/**
 * POST /v1/vtpass/verify-meter
 * Merchant verification for electricity meters. Requires authentication.
 */
router.post('/verify-meter', requireAuth, handleMerchantVerify);

/**
 * POST /v1/vtpass/verify-smartcard
 * Merchant verification for cable TV smartcards. Requires authentication.
 */
router.post('/verify-smartcard', requireAuth, handleMerchantVerify);

/**
 * POST /v1/vtpass/merchant-verify
 */
router.post('/merchant-verify', requireAuth, handleMerchantVerify);

/**
 * POST /v1/vtpass/verify
 */
router.post('/verify', requireAuth, handleMerchantVerify);

/**
 * GET /v1/vtpass/billers?category=electricity|tv
 * Proxy VTPass biller listing by category. Requires authentication.
 */
router.get('/billers', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const category = ((req.query.category as string) || 'electricity').toLowerCase();
  const identifierMap: Record<string, string> = {
    electricity: 'electricity-bill',
    'electricity-bill': 'electricity-bill',
    tv: 'tv-subscription',
    'tv-subscription': 'tv-subscription',
  };
  const identifier = identifierMap[category] || 'electricity-bill';

  if (config.vtpassApiKey && config.vtpassSecretKey) {
    try {
      const vtpassRes = await fetch(`${config.vtpassBaseUrl}/services?identifier=${identifier}`, {
        headers: {
          'api-key': config.vtpassApiKey,
          'secret-key': config.vtpassSecretKey,
        },
      });

      const data = await vtpassRes.json();
      res.status(vtpassRes.status).json(data);
      return;
    } catch (err: any) {
      res.status(502).json({ response_description: `VTPass Gateway Error: ${err?.message || 'Upstream connection failed'}` });
      return;
    }
  }

  // Mock response when credentials absent
  const isTv = category === 'tv';
  res.status(200).json({
    code: '000',
    response_description: 'SUCCESSFUL',
    content: isTv
      ? [
          { serviceID: 'dstv', name: 'DSTV' },
          { serviceID: 'gotv', name: 'GOtv' },
          { serviceID: 'startimes', name: 'Startimes' },
        ]
      : [
          { serviceID: 'ikeja-electric', name: 'Ikeja Electric' },
          { serviceID: 'eko-electric', name: 'Eko Electricity' },
          { serviceID: 'abuja-electric', name: 'Abuja Electricity' },
        ],
  });
});

/**
 * POST /v1/vtpass/pay
 * Proxies utility bill / airtime payment to VTPass. (Requires Firebase Auth)
 */
router.post('/pay', requireAuth, handleVtpassPay);

/**
 * POST /v1/vtpass/requery
 * Queries transaction status from VTPass. (Requires Firebase Auth)
 */
router.post('/requery', requireAuth, handleVtpassRequery);

export default router;
