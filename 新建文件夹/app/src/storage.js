const DB_NAME = "ios_quiz_tool";
const DB_VERSION = 1;
const STORES = ["questions", "papers", "attempts", "reviewItems", "settings"];

function openDb() {
  return new Promise((resolve, reject) => {
    if (!("indexedDB" in window)) {
      reject(new Error("IndexedDB unavailable"));
      return;
    }

    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const store of STORES) {
        if (!db.objectStoreNames.contains(store)) db.createObjectStore(store, { keyPath: "id" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function withStore(storeName, mode, callback) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, mode);
    const store = tx.objectStore(storeName);
    const result = callback(store);
    tx.oncomplete = () => resolve(result);
    tx.onerror = () => reject(tx.error);
  });
}

function readLocalList(storeName) {
  return JSON.parse(localStorage.getItem(storeName) || "[]");
}

function writeLocalList(storeName, list) {
  localStorage.setItem(storeName, JSON.stringify(list));
}

export async function saveItem(storeName, item) {
  try {
    await withStore(storeName, "readwrite", (store) => store.put(item));
  } catch {
    const list = readLocalList(storeName).filter((entry) => entry.id !== item.id);
    list.push(item);
    writeLocalList(storeName, list);
  }
}

export async function saveItems(storeName, items) {
  for (const item of items) {
    await saveItem(storeName, item);
  }
}

export async function getAllItems(storeName) {
  try {
    const db = await openDb();
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(storeName, "readonly");
      const req = tx.objectStore(storeName).getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => reject(req.error);
    });
  } catch {
    return readLocalList(storeName);
  }
}

export async function clearStore(storeName) {
  try {
    await withStore(storeName, "readwrite", (store) => store.clear());
  } catch {
    localStorage.removeItem(storeName);
  }
}

export async function exportBackup() {
  const backup = {};
  for (const storeName of STORES) {
    backup[storeName] = await getAllItems(storeName);
  }
  return backup;
}
