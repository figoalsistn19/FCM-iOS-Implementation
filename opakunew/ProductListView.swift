import SwiftUI
import FBSDKCoreKit // <-- LANGKAH 1: Tambahkan import ini

// MODEL DATA PRODUK (tetap sama)
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let price: Double
    let imageName: String

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: price)) ?? "Rp0"
    }
}

// VIEW UNTUK SATU BARIS PRODUK (tetap sama)
struct ProductRowView: View {
    let product: Product
    var body: some View {
        HStack(spacing: 16) {
            Image(product.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 8) {
                Text(product.name).font(.headline)
                Text(product.description).font(.subheadline).foregroundColor(.secondary)
                Text(product.formattedPrice).font(.headline).foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
    }
}

// VIEW UTAMA UNTUK DAFTAR PRODUK (dengan modifikasi)
struct ProductListView: View {
    let products: [Product] = [
        Product(name: "Kamera Pro", description: "Kamera canggih 45MP.", price: 25500000, imageName: "camera"),
        Product(name: "Headphone Bass", description: "Suara jernih dan bass mendalam.", price: 1250000, imageName: "headphones"),
        Product(name: "Smartwatch Gen 5", description: "Lacak kesehatan dari pergelangan tangan.", price: 3100000, imageName: "watch")
    ]

    var body: some View {
        List(products) { product in
            ProductRowView(product: product)
                // LANGKAH 2: Tambahkan .onTapGesture untuk membuat baris bisa diklik
                .onTapGesture {
                    logProductClickEvent(product: product)
                }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Daftar Produk")
    }
    
    // LANGKAH 3: Buat fungsi untuk mengirim event ke Meta
    private func logProductClickEvent(product: Product) {
        // 1. Tentukan nama event kustom Anda
        let eventName = AppEvents.Name("product_clicked")
        
        // 2. Siapkan parameter yang ingin Anda kirim.
        // Untuk event kustom, lebih baik menggunakan kunci parameter kustom juga.
        let parameters: [AppEvents.ParameterName: Any] = [
            AppEvents.ParameterName("product_id"): product.id.uuidString,
            AppEvents.ParameterName("product_name"): product.name,
            AppEvents.ParameterName("product_price"): product.price,
            AppEvents.ParameterName("currency"): "IDR"
        ]
        
        // 3. Kirim event kustom Anda
        AppEvents.shared.logEvent(eventName, parameters: parameters)
        
        print("✅ Custom Event 'product_clicked' untuk produk '\(product.name)' dikirim ke Meta.")
    }
}

// PREVIEW (tetap sama)
struct ProductListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProductListView()
        }
    }
}
