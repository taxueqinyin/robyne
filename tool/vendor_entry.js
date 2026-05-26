import CryptoJS from 'crypto-js';
import dayjs from 'dayjs';
import he from 'he';
import * as cheerio from 'cheerio';

globalThis.__robyneModules = globalThis.__robyneModules || {};
globalThis.__robyneModules['crypto-js'] = CryptoJS;
globalThis.__robyneModules.dayjs = dayjs;
globalThis.__robyneModules.he = he;
globalThis.__robyneModules.cheerio = cheerio;
